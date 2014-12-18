//
//  ViewController.h
//  RotateAndZoom
//
//  Created by ronaldo on 12/16/14.
//  Copyright (c) 2014 ronaldo. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController<UIGestureRecognizerDelegate>

@property(nonatomic,assign) CGFloat minimumScale;
@property(nonatomic,assign) CGFloat maximumScale;
@property(nonatomic, assign) CGRect initialImageFrame;
@property(nonatomic, assign) CGPoint topLeft;
@property(nonatomic, assign) CGPoint topRight;
@property(nonatomic, assign) CGPoint bottomLeft;
@property(nonatomic, assign) CGPoint bottomRight;
@end

