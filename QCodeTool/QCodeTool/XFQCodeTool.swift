//
//  XFQCodeTool.swift
//  QCodeTool
//
//  Created by yxf on 2018/1/23.
//  Copyright © 2018年 k_yan. All rights reserved.
//

import UIKit
import CoreImage
import AVFoundation


protocol XFQCodeToolDelegate {
    func scanStopped(tool:XFQCodeTool)
}

//L：7% M：15 Q：25 H：30
enum XFQCodeCorrectionLevel {
    case XFQCodeCorrectionLow
    case XFQCodeCorrectionMiddle
    case XFQCodeCorrectionQualified
    case XFQCodeCorrectionHigh
}
typealias XFScanResultBlock = (String) -> ()

class XFQCodeTool: NSObject {
    ///单例
    static let shareInstance = XFQCodeTool.init()
    var isNeedStroke : Bool = false
    var scanResultBlock : XFScanResultBlock?
    var delegate : XFQCodeToolDelegate?
    
    
    //输入输出流
    lazy var session: AVCaptureSession = {
        let session = AVCaptureSession.init()
        return session
    }()
    
    //输入设备
    lazy var input: AVCaptureDeviceInput? = {
        //摄像头设备
        guard let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) else{
            print("获取视频设备失败")
            return nil
        }
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
}

//MARK: 公开api
extension XFQCodeTool{
    ///生成二维码
    class func createQcode(msg:String,correctionLevel:XFQCodeCorrectionLevel?,centerImg:UIImage?) -> UIImage? {
        //1.创建二维码滤镜
        let filter = CIFilter.init(name: "CIQRCodeGenerator")
        //1.1 恢复滤镜默认设置
        filter?.setDefaults()
        
        //2.设置滤镜输入数据
        //2.1通过kvc设置，且只支持Data数据类型
        let data = msg.data(using: String.Encoding.utf8)
        filter?.setValue(data, forKey: "inputMessage")
        
        //2.2 设置二维码的纠错率
        let level = correctionLevel ?? XFQCodeCorrectionLevel.XFQCodeCorrectionMiddle
        var correcttionV = "M"
        switch level {
        case XFQCodeCorrectionLevel.XFQCodeCorrectionLow:
            correcttionV = "L"
        case XFQCodeCorrectionLevel.XFQCodeCorrectionQualified:
            correcttionV = "Q"
        case XFQCodeCorrectionLevel.XFQCodeCorrectionHigh:
            correcttionV = "H"
        default:
            correcttionV = "M"
        }
        
        filter?.setValue(correcttionV, forKey: "inputCorrectionLevel")
        
        //3.从二维码滤镜里面，获取结果图片
        guard var image = filter?.outputImage else{
            return nil
        }
        
        //3.1图片处理
        //图片可能比较模糊，需要放大图片,图片的大小根据数据内容而定，数据越多，图片越大
        var resultImage = UIImage.init(ciImage: image)
        if resultImage.size.width < 400 {
            let rate = 400 / resultImage.size.width
            let transform = CGAffineTransform.init(scaleX: rate, y: rate)
            image = image.applying(transform)
            resultImage = UIImage.init(ciImage: image)
        }
        
        //4.显示图片
        guard let centerImg = centerImg else { return resultImage }
        return self.getNewImage(sourceImg: resultImage, centerImg: centerImg)
    }

    ///识别图片中的二维码
    class func detectorQcodeInImg(image:UIImage,isNeedStroke:Bool?) -> (resutMsg:[String],resultImg:UIImage?){
        //0. 获取需要识别的图片
        guard let imageCI = CIImage.init(image: image) else{
            return ([String](),nil)
        }
        
        //开始识别
        //1.创建一个二维码探测器
        let detector = CIDetector.init(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy : CIDetectorAccuracyHigh])
        
        //2.直接探测二维码特征
        guard let features = detector?.features(in: imageCI) else{
            return ([String](),nil)
        }
        
        guard let qfeatures = features as? [CIQRCodeFeature] else { return ([String](),nil)  }
        
        var resultMsgs = [String]()
        for qcodeFeature in qfeatures {
            if let msg = qcodeFeature.messageString{
                resultMsgs.append(msg)
            }
        }
        
        //3.处理扫描结果
        if isNeedStroke != true {
            return (resultMsgs,nil)
        }
        let resultImg = handleDetectorResult(image: image, features: qfeatures)
        return (resultMsgs,resultImg)
    }

    ///设置可识别区域(不设置就是整个区域都可以被识别)
    func interestRect(withRect rect:CGRect) -> CGRect{
        //注意这里的每个参数的取值都是对应的比例
        //坐标系为横屏状态下的坐标系
        let screenBounds = UIScreen.main.bounds
        let x = rect.origin.x / screenBounds.width
        let y = rect.origin.y / screenBounds.height
        let width = rect.width / screenBounds.width
        let height = rect.height / screenBounds.height
        return CGRect.init(x: y, y: x, width: height, height: width)
    }
    
    ///扫描二维码
    func scanQcode(view:UIView,interestRect:CGRect?,isNeedStroke:Bool?, scanResult:@escaping XFScanResultBlock) -> Void {
        self.isNeedStroke = isNeedStroke == true
        self.scanResultBlock = scanResult
        
        guard let input = input else {
            return
        }
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
        if let interestRect = interestRect {
            output.rectOfInterest = interestRect
        }

        //5.启动会话 ，监听元数据处理后的结果
        session.startRunning()
    }
    
    func stopScanQcode() {
        session.stopRunning()
        if self.delegate == nil {
            self.delegate?.scanStopped(tool: self)
        }
    }
}

extension XFQCodeTool : AVCaptureMetadataOutputObjectsDelegate{
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        //metadataObjects元数据输出结果
        if metadataObjects.count == 0 {
            return
        }
        //停止扫描
        stopScanQcode()
        
        for obj in metadataObjects {
            //1.将扫描到的二维码的坐标转换为我们能够识别的坐标
            let qcodeObj = previewLayer?.transformedMetadataObject(for: obj)
            
            guard let resultCodeObj = qcodeObj as? AVMetadataMachineReadableCodeObject else{ continue }
            
            //2.根据元数据对象，绘制二维码边框
            if self.isNeedStroke == true {
               strokeQcodeZone(resutObj: resultCodeObj)
            }
            
            //3.输出二维码信息
            if let scanResultBlock = scanResultBlock  {
                scanResultBlock(resultCodeObj.stringValue ?? "")
            }
        }
    }
    
}

//MARK: 私有方法
extension XFQCodeTool{
    
    //需要注意的是前置图片的大小不能过大，否则超出二维码纠错率就不能识别了
    //同理添加背景图片，先画背景图片，再画其它图片，最后合成一张图片
    ///二维码中添加前置图片
    class fileprivate func getNewImage(sourceImg:UIImage,centerImg:UIImage) -> UIImage? {
        let size = sourceImg.size
        //1.开启图形上下文
        UIGraphicsBeginImageContext(size)
        
        //2.绘制大图片
        sourceImg.draw(in: CGRect.init(x: 0, y: 0, width: size.width, height: size.height))
        
        //3.绘制小图片
        let width = centerImg.size.width;
        let height = centerImg.size.height;
        let x = (size.width - width) / 2
        let y = (size.height - height) / 2
        let centerRect = CGRect.init(x: x, y: y, width: width, height: height)
        centerImg.draw(in: centerRect)
        
        //4.取出结果图片
        let resultImg =
            UIGraphicsGetImageFromCurrentImageContext()
        
        //5.关闭上下文
        UIGraphicsEndImageContext()
        
        //6.返回结果
        return resultImg
    }
    
    ///给原图片中的二维码描边
    class fileprivate func handleDetectorResult(image : UIImage, features:[CIQRCodeFeature])-> UIImage?{
        let size = image.size
        UIGraphicsBeginImageContext(size)
        image.draw(at: CGPoint.init())
        
        //坐标变换
        //CIQRCodeFeature 的坐标是相对于图片的坐标，原点在左下角
        //context 的坐标在左上角
        //需要进行坐标变换，即沿着x轴进行翻转
        let context = UIGraphicsGetCurrentContext()
        context?.scaleBy(x: 1, y: -1)
        context?.translateBy(x: 0, y: -size.height)
        
        for feature in features {
            //CIQRCodeFeature
            //feature.bounds 二维码在图片中的位置
            //feature.messageString 二维码的信息
            let bPath = UIBezierPath.init(rect: feature.bounds)
            bPath.lineWidth = 5
            UIColor.red.setStroke()
            bPath.stroke()
        }
        let resultImg = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resultImg
    }
  
    ///给扫描到的二维码描边
    func strokeQcodeZone(resutObj : AVMetadataMachineReadableCodeObject) {
        if resutObj.corners.count == 0 {
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
            print("二维码角点数为0")
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
}
