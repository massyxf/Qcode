//
//  QFindViewController.swift
//  二维码
//
//  Created by yxf on 2018/1/19.
//  Copyright © 2018年 k_yan. All rights reserved.
//

import UIKit

class QFindViewController: UIViewController {

    @IBOutlet weak var qImgView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        qImgView.image = UIImage.init(named: "2.png")
    }
    @IBAction func detectorImg(_ sender: Any) {
        //0. 获取需要识别的图片
        guard let image = qImgView.image else{
            return
        }
        guard let imageCI = CIImage.init(image: image) else{
            return
        }
        
        //开始识别
        //1.创建一个二维码探测器
        let detector = CIDetector.init(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy : CIDetectorAccuracyHigh])
        
        //2.直接探测二维码特征
        guard let features = detector?.features(in: imageCI) else{
            return
        }
        print(features)
        
        guard let qfeatures = features as? [CIQRCodeFeature] else { return  }
        //3.把识别的二维码描边
        qImgView.image = addQView(image: image, features: qfeatures)
    }
}

extension QFindViewController{
    fileprivate func addQView(image : UIImage, features:[CIQRCodeFeature])-> UIImage?{
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
}

