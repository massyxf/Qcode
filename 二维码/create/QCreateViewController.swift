//
//  QCreateViewController.swift
//  二维码
//
//  Created by yxf on 2018/1/19.
//  Copyright © 2018年 k_yan. All rights reserved.
//

import UIKit
import CoreImage

class QCreateViewController: UIViewController {

    @IBOutlet weak var qImageView: UIImageView!
    
    @IBOutlet weak var qTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        qImageView.backgroundColor = UIColor.red
        qTextView.delegate = self;
        qTextView.returnKeyType = .done
    }
    
//    自定义二维码：所谓自定义二维码，就是指给二维码添加一些图片（前景或者背景图片），或者改变下颜色。
//    可以添加前景图片的前提是因为二维码具备一定的纠错率：
//    1.如果二维码被部分遮挡，可以根据其它部分，计算出遮挡部分内容
//    2.但是要保证三个角不能被遮挡，三个角用作扫描定位使用（可能用户倒着拍，写着拍等等）
//    可以设置二维码的纠错率inputCorrectionLevel：L M Q H
//    L：7%的字码可被修正 M：15 Q：25 H：30
    
    @IBAction func createQcode(_ sender: Any) {
    
        //1.创建二维码滤镜
        let filter = CIFilter.init(name: "CIQRCodeGenerator")
        //1.1 恢复滤镜默认设置
        filter?.setDefaults()
        
        //2.设置滤镜输入数据
        //2.1通过kvc设置，且只支持Data数据类型
        let data = qTextView.text.data(using: String.Encoding.utf8)
        filter?.setValue(data, forKey: "inputMessage")
        
        //2.2 设置二维码的纠错率
        filter?.setValue("M", forKey: "inputCorrectionLevel")
        
        //3.从二维码滤镜里面，获取结果图片
        guard var image = filter?.outputImage else{
            return
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
        
        print(resultImage)
        //4.显示图片
        qImageView.image = self.getNewImage(sourceImg:resultImage,centerImg:UIImage.init(named: "1.png")!)
        
//        qImageView.image = resultImage
    
    }
}

extension QCreateViewController{
    //二维码中添加前置图片
    //需要注意的是前置图片的大小不能过大，否则超出二维码纠错率就不能识别了
    //同理添加背景图片，先画背景图片，再画其它图片，最后合成一张图片
    fileprivate func getNewImage(sourceImg:UIImage,centerImg:UIImage) -> UIImage? {
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
}

extension QCreateViewController : UITextViewDelegate{
    func textViewDidChange(_ textView: UITextView) {
        if textView.text.hasSuffix("\n") {
            textView.endEditing(true)
        }
    }
}


