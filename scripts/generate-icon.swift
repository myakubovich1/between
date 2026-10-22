import Foundation
import CoreGraphics
import ImageIO
let ctx = CGContext(data:nil,width:1024,height:1024,bitsPerComponent:8,bytesPerRow:4096,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(CGColor(red:0.08,green:0.27,blue:0.22,alpha:1));ctx.fill(CGRect(x:0,y:0,width:1024,height:1024))
ctx.setFillColor(CGColor(red:0.94,green:0.96,blue:0.88,alpha:1))
for (rect,radius) in [(CGRect(x:266,y:232,width:155,height:560),CGFloat(77)),(CGRect(x:471,y:232,width:287,height:255),CGFloat(127)),(CGRect(x:471,y:537,width:210,height:255),CGFloat(105))] { ctx.addPath(CGPath(roundedRect:rect,cornerWidth:radius,cornerHeight:radius,transform:nil));ctx.fillPath() }
ctx.setFillColor(CGColor(red:0.83,green:0.65,blue:0.37,alpha:1));ctx.fillEllipse(in:CGRect(x:715,y:703,width:85,height:85))
let image=ctx.makeImage()!
let destination=CGImageDestinationCreateWithURL(URL(fileURLWithPath:CommandLine.arguments[1]) as CFURL,"public.png" as CFString,1,nil)!
CGImageDestinationAddImage(destination,image,nil);CGImageDestinationFinalize(destination)
