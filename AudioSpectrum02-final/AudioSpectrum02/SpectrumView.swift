//
// AudioSpectrum02
// A demo project for blog: https://juejin.im/post/5c1bbec66fb9a049cb18b64c
// Created by: potato04 on 2019/1/30
//

import UIKit
import Charts
import QuartzCore
import CoreGraphics

class SpectrumView: UIView {
    

    var barWidth: CGFloat = 3.0
    var space: CGFloat = 1.0
    
    private let bottomSpace: CGFloat = 0.0
    private let topSpace: CGFloat = 0.0
    
    var leftGradientLayer = CAGradientLayer()
    var rightGradientLayer = CAGradientLayer()
    
    var averageAngle:Double = 0
    var r:CGFloat = 0
    var R:CGFloat = 0.0
    var maxH:CGFloat = 0
    
    

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()
    
    
    
    var frequencyBands = 40 {
        didSet {
            averageAngle = Double(180.0/Double(frequencyBands))
        }
    }

    
    var spectra:[[Float]]? {
        didSet {
//            if let spectra = spectra {
//                // left channel
//                let leftPath = UIBezierPath()
//                for (i, amplitude) in spectra[0].enumerated() {
//                    let x = CGFloat(i) * (barWidth + space) + space
//                    let y = translateAmplitudeToYPosition(amplitude: amplitude)
//                    let bar = UIBezierPath(rect: CGRect(x: x, y: y, width: barWidth, height: bounds.height - bottomSpace - y))
//                    leftPath.append(bar)
//                }
//                let leftMaskLayer = CAShapeLayer()
//                leftMaskLayer.path = leftPath.cgPath
//                leftGradientLayer.frame = CGRect(x: 0, y: topSpace, width: bounds.width, height: bounds.height - topSpace - bottomSpace)
//                leftGradientLayer.mask = leftMaskLayer
//
//                // right channel
//                if spectra.count >= 2 {
//                    let rightPath = UIBezierPath()
//                    for (i, amplitude) in spectra[1].enumerated() {
//                        let x = CGFloat(spectra[1].count - 1 - i) * (barWidth + space) + space
//                        let y = translateAmplitudeToYPosition(amplitude: amplitude)
//                        let bar = UIBezierPath(rect: CGRect(x: x, y: y, width: barWidth, height: bounds.height - bottomSpace - y))
//                        rightPath.append(bar)
//                    }
//                    let rightMaskLayer = CAShapeLayer()
//                    rightMaskLayer.path = rightPath.cgPath
//                    rightGradientLayer.frame = CGRect(x: 0, y: topSpace, width: bounds.width, height: bounds.height - topSpace - bottomSpace)
//                    rightGradientLayer.mask = rightMaskLayer
//                }
//            }
            
            
            if let _ = spectra {

                
                self.setNeedsDisplay()
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        setupView()

      
    }
    
//    init(frame: CGRect, type:Int, frequencyBands:Int) {
//        self.frequencyBands = frequencyBands
//
//        super.init(frame: frame)
//        averageAngle = Double(180.0/Double(frequencyBands))
//        r = (bounds.size.width-170)/2
//        R = 0.0
//        maxH = bounds.size.width/2-r
//
//    }
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        r = (bounds.size.width-170)/2
        R = 0.0
        maxH = bounds.size.width/2-r
//        rightGradientLayer.colors = [UIColor.init(red: 52/255, green: 232/255, blue: 158/255, alpha: 1.0).cgColor,
//                                     UIColor.init(red: 15/255, green: 52/255, blue: 67/255, alpha: 1.0).cgColor]
//        rightGradientLayer.locations = [0.6, 1.0]
//        self.layer.addSublayer(rightGradientLayer)
//
//        leftGradientLayer.colors = [UIColor.init(red: 194/255, green: 21/255, blue: 0/255, alpha: 1.0).cgColor,
//                                    UIColor.init(red: 255/255, green: 197/255, blue: 0/255, alpha: 1.0).cgColor]
//        leftGradientLayer.locations = [0.6, 1.0]
//        self.layer.addSublayer(leftGradientLayer)
    
        
        
    }
    
    private lazy var pointsArray:[[(start:CGPoint,end:CGPoint)]] = {
        let pointsArray = [[(start:CGPoint,end:CGPoint)]](repeating: [(start:CGPoint,end:CGPoint)](repeating: (CGPoint (x:0, y:0), CGPoint (x:0, y:0)), count: self.frequencyBands), count: 2)
        return pointsArray
    }()
    
//    private var pointsArray = [[(start:CGPoint,end:CGPoint)]](repeating: [(start:CGPoint,end:CGPoint)](repeating: (CGPoint (x:0, y:0), CGPoint (x:0, y:0)), count: 60), count: 2)
    
//    private var pointsArray = [(startPoint:CGPoint,end:CGPoint)](repeating: (CGPoint (x:0, y:0), CGPoint (x:0, y:0)), count: 80)

    private func getPointsArray(spectra:[[Float]]) {
        
        for (j,spe) in spectra.enumerated() {
            for (i, amplitude) in spe.enumerated() {
                
//                var angle:Double = -averageAngle*Double(i)*Double.pi/180
                var angle:Double
                if j == 1 {
                    angle = (180+averageAngle*Double(i))*Double.pi/180
//                    break
                } else {
                    angle = averageAngle*Double(i)*Double.pi/180
                    
                }
                let sinValue = sin(angle)
                let cosValue = cos(angle)
                
                let x = bounds.midX+r*sinValue
                let y = bounds.size.height/2-r*cosValue
                var X: CGFloat = 0.0
                var Y: CGFloat = 0.0
                 
         
                if amplitude < Float(4/frequencyBands) {
                    R = r+4
                } else {
                    R = r+CGFloat(amplitude * Float(maxH))
                }
                
                X = bounds.midX+R*sinValue
                Y = bounds.size.height/2-R*cosValue
                
              
                let startPoint =  CGPoint (x:x, y:y)
                let endPoint =  CGPoint (x:X, y:Y)
                pointsArray[j][i] = (startPoint,endPoint)
            }
        }
        

        
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        
        //获取绘图上下文
        guard let context = UIGraphicsGetCurrentContext(),let spectra = spectra else {
            return
        }

        getPointsArray(spectra: spectra)
        for (j, item) in pointsArray.enumerated() {
            for (i, point) in item.enumerated() {
                let path = CGMutablePath()
                //创建并设置路径
                path.move(to: point.start)
                path.addLine(to: point.end)
                context.addPath(path)
            }
//            if j == 0 {
//                context.setStrokeColor(UIColor.orange.cgColor)
//                //设置线条宽度
//                context.setLineWidth(4)
//                //设置填充颜色
//                context.setFillColor(UIColor.red.cgColor)
//                //设置端点样式
//                context.setLineCap(.round)
//                //绘制路径
//                context.strokePath()
//            } else {
//                context.setStrokeColor(UIColor.red.cgColor)
//                //设置线条宽度
//                context.setLineWidth(4)
//                //设置填充颜色
//                context.setFillColor(UIColor.red.cgColor)
//                //设置端点样式
//                context.setLineCap(.round)
//                //绘制路径
//                context.strokePath()
//            }
        }

        
//        //定义渐变颜色数组
//        let colors = [  204.0 / 255.0, 224.0 / 255.0, 244.0 / 255.0, 1.00,
//                        29.0 / 255.0, 156.0 / 255.0, 215.0 / 255.0, 1.00,
//                        0.0 / 255.0,  50.0 / 255.0, 126.0 / 255.0, 1.00,]
//
//
//        //使用rgb颜色空间
//        let colorSpace = CGColorSpaceCreateDeviceRGB ()
//        //颜色数组（这里使用三组颜色作为渐变）fc6820
//        let compoents:[ CGFloat ] = [0xfc/255, 0x68/255, 0x20/255, 1,
//                                   0xfe/255, 0xd3/255, 0x2f/255, 1,
//                                   0xb1/255, 0xfc/255, 0x33/255, 1]
//        //没组颜色所在位置（范围0~1)
//        let locations:[ CGFloat ] = [0,0.5,1]
//        //生成渐变色（count参数表示渐变个数）
//        let gradient = CGGradient (colorSpace: colorSpace, colorComponents: compoents,
//                                  locations: locations, count: locations.count)!
//
//        //渐变开始位置
//        let start = CGPoint (x: self .bounds.minX, y: self .bounds.minY)
//        //渐变结束位置
//        let end = CGPoint (x: self .bounds.maxX, y: self .bounds.minY)
//        //绘制渐变
////        context.drawLinearGradient(gradient, start: start, end: end,
////                                   options: .drawsBeforeStartLocation)
//        context.drawRadialGradient(gradient, startCenter: start, startRadius: r, endCenter: end, endRadius: 80, options: .drawsBeforeStartLocation)
        //设置线条颜色
        context.setStrokeColor(UIColor.orange.cgColor)
//        context.setStrokeColor(compoents)
//
        //设置线条宽度
        context.setLineWidth(4)
        //设置填充颜色
//        context.setFillColor(compoents)
        //设置端点样式
        context.setLineCap(.round)
        //绘制路径
        context.strokePath()
//
        
//            context.drawPath(using: .stroke)



    }
    
    private func translateAmplitudeToYPosition(amplitude: Float) -> CGFloat {
        let barHeight: CGFloat = CGFloat(amplitude) * (bounds.height - bottomSpace - topSpace)
        return bounds.height - bottomSpace - barHeight
    }
    
}
