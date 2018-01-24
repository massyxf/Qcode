//
//  QScanViewController.swift
//  二维码
//
//  Created by yxf on 2018/1/19.
//  Copyright © 2018年 k_yan. All rights reserved.
//

import UIKit
import AVFoundation

class QScanViewController: UIViewController {
    @IBOutlet weak var scanBgView: UIView!
    @IBOutlet weak var scanImgView: UIImageView!
    @IBOutlet weak var scanImgBottomCons: NSLayoutConstraint!
    @IBOutlet weak var msgLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    //输入输出流
    lazy var session: AVCaptureSession = {
        let session = AVCaptureSession.init()
        return session
    }()
    
    //输入设备
    lazy var input: AVCaptureDeviceInput? = {
        //摄像头设备
        let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        //将摄像头设备设置为输入设备
        var input : AVCaptureDeviceInput? = nil
        do{
            input = try AVCaptureDeviceInput.init(device: device)
        } catch{
            print("创建输入设备失败")
        }
        return input
    }()
    
    //元数据输出处理，在这里处理扫描到的结果
    lazy var output: AVCaptureMetadataOutput = {
        
        var captureMetaDataOutput = AVCaptureMetadataOutput.init()
        //设置元数据输出处理的代理
        captureMetaDataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        
        return captureMetaDataOutput
    }()
    
    
    //预览图层
    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        let previewLayer = AVCaptureVideoPreviewLayer.init(session: self.session)
        return previewLayer
    }()
    
    @IBAction func startScan(_ sender: Any) {
        startScanQcode()
    }
    
    @IBAction func stopScan(_ sender: Any) {
        endScanAnimation()
    }
}

//MARK: 扫描动画控制,扫描过程中的UI
extension QScanViewController{
    fileprivate func scanAnimation() {
        endScanAnimation()
        scanImgBottomCons.constant = self.scanImgView.frame.height
        view.layoutIfNeeded()
        UIView.animate(withDuration: 1.3) {
            UIView.setAnimationRepeatCount(MAXFLOAT)
            self.scanImgBottomCons.constant = -self.scanImgView.frame.height
            self.view.layoutIfNeeded()
        }
    }
    
    fileprivate func endScanAnimation() {
        scanImgView.layer.removeAllAnimations()
        scanImgBottomCons.constant = 0
        view.layoutIfNeeded()
    }
    
    func addResultObj(resutObj : AVMetadataMachineReadableCodeObject) {
        if resutObj.corners == nil || resutObj.corners.count == 0 {
            return
        }
        
        //0.创建图层
        let showLayer  = CAShapeLayer.init()
        showLayer.lineWidth = 5
        showLayer.strokeColor = UIColor.red.cgColor
        showLayer.fillColor = UIColor.clear.cgColor
        
        //1.创建图层路径，并根据四角画线
        let path = UIBezierPath.init()
        
        //2.解析点
        var resultPoints = [CGPoint]()
        for pointDic in resutObj.corners {
            //将点字典转换成为点
            guard let point = CGPoint.init(dictionaryRepresentation: pointDic as! CFDictionary) else {
                print("转换二维码的角点失败")
                return
            }
            resultPoints.append(point)
        }
        
        guard resultPoints.count > 0 else {
            print("二维码角点为0")
            return
        }
        
        //3.画线
        var index = 0
        for point in resultPoints {
            if index == 0{//移动到第一个点
                path.move(to: point)
            }else{
                path.addLine(to: point)
            }
            index += 1
        }
        //4.关闭路径
        path.close()
        
        //5.设置路径
        showLayer.path = path.cgPath
        
        //6.添加到图层
        previewLayer?.addSublayer(showLayer)
    }
    
    func removeResultObj() {
        guard let subLayers = previewLayer?.sublayers else { return }
        for sublayer in subLayers {
            if sublayer.isKind(of: CAShapeLayer.self){
                sublayer.removeFromSuperlayer()
            }
        }
    }
}

//MARK: 扫描逻辑
extension QScanViewController{
    func startScanQcode() {
        //0.开始扫描动画
        scanAnimation()
        
        //1.使用会话，添加输入和输出
        if session.canAddInput(input) && session.canAddOutput(output) {
            session.addInput(input)
            session.addOutput(output)
        }else{ return }
        
        //2.设置元数据处理类型（表示元数据输出对象，可以处理什么样的数据，比如二维码，条形码）
        //注意： 此项设置，只能在session添加输出设备之后设置，否则扫描无效
        //output.availableMetadataObjectTypes 所有可支持的扫描类型
        output.metadataObjectTypes = [AVMetadataObjectTypeQRCode]
        
        //3.添加视频预览图层
        guard let previewLayer = self.previewLayer else { return }
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
        
        //4.设置扫描区域
        //注意这里的每个参数的取值都是对应的比例
        //坐标系为横屏状态下的坐标系
        let screenBounds = UIScreen.main.bounds
        let x = scanBgView.frame.origin.x / screenBounds.width
        let y = scanBgView.frame.origin.y / screenBounds.height
        let width = scanBgView.frame.width / screenBounds.width
        let height = scanBgView.frame.height / screenBounds.height
        let rect = CGRect.init(x: y, y: x, width: height, height: width)
        output.rectOfInterest = rect
        print(rect)
        //5.启动会话 ，监听元数据处理后的结果
        session.startRunning()
    }
    
    func stopQcodeScan() {
        endScanAnimation()
        session.stopRunning()
    }
}

//MARK: 输出元数据处理的代理，获取输出数据
extension QScanViewController : AVCaptureMetadataOutputObjectsDelegate{
    func captureOutput(_ output: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        
        //移除之前添加的扫描框
        removeResultObj()
        
        //metadataObjects元数据输出结果
        if metadataObjects.count == 0 {
            return
        }
        //停止扫描
        session.stopRunning()
//        endScanAnimation()
//        previewLayer?.removeFromSuperlayer()
        
        for obj in metadataObjects {
            guard let obj = obj as? AVMetadataObject else{ continue }
            //1.将扫描到的二维码的坐标转换为我们能够识别的坐标
            let qcodeObj = previewLayer?.transformedMetadataObject(for: obj)
            
            guard let resultCodeObj = qcodeObj as? AVMetadataMachineReadableCodeObject else{ continue }
            
            //2.根据元数据对象，绘制二维码边框
            addResultObj(resutObj: resultCodeObj)
            
            //3.输出二维码信息
            msgLabel.text = resultCodeObj.stringValue
        }
    }
}



