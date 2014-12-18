//
//  ViewController.m
//  RotateAndZoom
//
//  Created by ronaldo on 12/16/14.
//  Copyright (c) 2014 ronaldo. All rights reserved.
//

#import "ViewController.h"
#import "UIView+Addition.h"

typedef struct {
    CGPoint tl,tr,bl,br;
} Rectangle;

@interface ViewController ()
@property(nonatomic,assign) NSUInteger gestureCount;
@property(nonatomic, assign) CGAffineTransform validTransform;
@property(nonatomic) CGRect cropRect;

@property (weak, nonatomic) IBOutlet UIView *imageView;

@property(nonatomic,assign) CGPoint touchCenter;
@property(nonatomic,assign) CGPoint rotationCenter;
@property(nonatomic,assign) CGPoint scaleCenter;
@property(nonatomic,assign) CGFloat scale;
@property(nonatomic,assign) CGFloat minumumValidScale;
@end

@implementation ViewController {
    
    __weak IBOutlet UIView *_cropView;
    
    __weak IBOutlet UISlider *_slider;
    CGFloat _preRotation;
}

- (void)viewDidLoad {
    [super viewDidLoad];

}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    self.cropRect = _cropView.frame;
    
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    panRecognizer.cancelsTouchesInView = NO;
    panRecognizer.delegate = self;
//    [self.view addGestureRecognizer:panRecognizer];
    
    UIPinchGestureRecognizer *pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    pinchRecognizer.cancelsTouchesInView = NO;
    pinchRecognizer.delegate = self;
    [self.view addGestureRecognizer:pinchRecognizer];
    
    [self commonInit];
}

- (void)commonInit{
    
    self.scale = 1;
    self.minimumScale = 0.5;
    self.maximumScale = 5;
    
//    CGFloat radian = M_PI_4;
//    CGFloat width = _cropView.width*sinf(radian)+_cropView.height*cosf(radian);
//    CGFloat height = _cropView.height*sinf(radian)+_cropView.width*cosf(radian);
    
    
    self.imageView.size = CGSizeMake(280, 260);
    self.imageView.center = CGPointMake(_cropView.centerX+15, _cropView.centerY+10);
    self.initialImageFrame = self.imageView.frame;

}

- (IBAction)reset:(id)sender {
    _slider.value = 0;
    _preRotation = 0;
    self.imageView.transform = CGAffineTransformIdentity;
    self.imageView.frame = self.initialImageFrame;
}


- (IBAction)handlePan:(UIPanGestureRecognizer*)recognizer
{
    if([self handleGestureState:recognizer.state]) {
        CGPoint translation = [recognizer translationInView:self.imageView];
        CGAffineTransform transform = CGAffineTransformTranslate( self.imageView.transform, translation.x, translation.y);
        self.imageView.transform = transform;
        [self checkBoundsWithTransform:transform];
        [recognizer setTranslation:CGPointMake(0, 0) inView:self.view];
    }
}

- (IBAction)handlePinch:(UIPinchGestureRecognizer *)recognizer
{
    if([self handleGestureState:recognizer.state]) {
        if(recognizer.state == UIGestureRecognizerStateBegan){
            self.scaleCenter = self.touchCenter;
        }
        
        CGFloat deltaX = self.scaleCenter.x-self.imageView.bounds.size.width/2.0;
        CGFloat deltaY = self.scaleCenter.y-self.imageView.bounds.size.height/2.0;
        
        CGAffineTransform transform =  CGAffineTransformTranslate(self.imageView.transform, deltaX, deltaY);
        transform = CGAffineTransformScale(transform, recognizer.scale, recognizer.scale);
        transform = CGAffineTransformTranslate(transform, -deltaX, -deltaY);
        self.scale *= recognizer.scale;
        self.imageView.transform = transform;
        
        recognizer.scale = 1;
        
        [self checkBoundsWithTransform:transform];
    }
}



- (void)checkBoundsWithTransform:(CGAffineTransform)transform
{
    
    CGRect r1 = [self boundingBoxForRect:self.cropRect rotatedByRadians:[self imageRotation]];
    Rectangle r2 = [self applyTransform:transform toRect:self.initialImageFrame];
    
    CGAffineTransform t = CGAffineTransformMakeTranslation(CGRectGetMidX(self.cropRect), CGRectGetMidY(self.cropRect));
    t = CGAffineTransformRotate(t, -[self imageRotation]);
    t = CGAffineTransformTranslate(t, -CGRectGetMidX(self.cropRect), -CGRectGetMidY(self.cropRect));
    
    Rectangle r3 = [self applyTransform:t toRectangle:r2];
    
    if(CGRectContainsRect([self CGRectFromRectangle:r3],r1)) {
        self.validTransform = transform;
    }else{
        
    }
}

- (CGFloat)boundedScale:(CGFloat)scale;
{
    CGFloat boundedScale = scale;
    if(self.minimumScale > 0 && scale < self.minimumScale) {
        boundedScale = self.minimumScale;
    } else if(self.maximumScale > 0 && scale > self.maximumScale) {
        boundedScale = self.maximumScale;
    }
    return boundedScale;
}

- (BOOL)handleGestureState:(UIGestureRecognizerState)state
{
    BOOL handle = YES;
    switch (state) {
        case UIGestureRecognizerStateBegan:
            self.gestureCount++;
            break;
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded: {
            self.gestureCount--;
            handle = NO;
            if(self.gestureCount == 0) {
                CGFloat scale = [self boundedScale:self.scale];
                NSLog(@"bounded scale = %f, origin scale = %f", scale, self.scale);
                if(scale != self.scale) {
                    CGFloat deltaX = self.scaleCenter.x-self.imageView.bounds.size.width/2.0;
                    CGFloat deltaY = self.scaleCenter.y-self.imageView.bounds.size.height/2.0;
                    
                    CGAffineTransform transform =  CGAffineTransformTranslate(self.imageView.transform, deltaX, deltaY);
                    
                    transform = CGAffineTransformScale(transform, scale/self.scale, scale/self.scale);
                    transform = CGAffineTransformTranslate(transform, -deltaX, -deltaY);
                    [self checkBoundsWithTransform:transform];
                    self.view.userInteractionEnabled = NO;
                    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                        self.imageView.transform = self.validTransform;
                    } completion:^(BOOL finished) {
                        self.view.userInteractionEnabled = YES;
                        self.scale = scale;
                        self.minumumValidScale = scale;
                        NSLog(@"scale = %f", self.imageView.transform.a);
                    }];
                    
                } else {
                    self.view.userInteractionEnabled = NO;
                    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                        self.imageView.transform = self.validTransform;
                    } completion:^(BOOL finished) {
                        self.view.userInteractionEnabled = YES;
                    }];
                    
                    self.imageView.transform = self.validTransform;
                }
            }
        } break;
        default:
            break;
    }
    return handle;
}

- (CGPoint)topLeft {
    CGPoint topLeft = _cropView.bounds.origin;
    topLeft = [self.imageView convertPoint:topLeft fromView:_cropView];
    return topLeft;
}

- (CGPoint)bottomRight {
    CGPoint bottomRight = _cropView.bounds.origin;
    bottomRight.x += _cropView.bounds.size.width;
    bottomRight.y += _cropView.bounds.size.height;
    bottomRight = [self.imageView convertPoint:bottomRight fromView:_cropView];
    return bottomRight;
}

- (CGPoint)topRight{
    CGPoint topRight = _cropView.bounds.origin;
    topRight.x += _cropView.bounds.size.width;
    topRight = [self.imageView convertPoint:topRight fromView:_cropView];
    return topRight;
}

- (CGPoint)bottomLeft{
    CGPoint bottomLeft = _cropView.bounds.origin;
    bottomLeft.y += _cropView.bounds.size.height;
    bottomLeft = [self.imageView convertPoint:bottomLeft fromView:_cropView];
    return bottomLeft;
}

#define DEGREES_TO_RADIANS(angle) ((angle) / 180.0 * M_PI)
- (IBAction)valueChanged:(UISlider *)sender {
    NSLog(@"sender = %f", sender.value);
    CGFloat originRadian = DEGREES_TO_RADIANS(sender.value-_preRotation);
    _preRotation = sender.value;
    
    self.imageView.transform = CGAffineTransformRotate(self.imageView.transform, originRadian);
    
    
    CGPoint topLeft = self.topLeft;
    if (topLeft.x < 0) {
        CGFloat diagonal = fabsf(topLeft.x);
        CGFloat radian = DEGREES_TO_RADIANS(sender.value);
        CGFloat offsetX = -diagonal/cosf(radian);
        self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, offsetX, 0);
    }

    
    CGPoint topRight = self.topRight;
    
    if (topRight.y < 0) {
        CGFloat diagonal = fabsf(topRight.y);
        CGFloat radian = DEGREES_TO_RADIANS(sender.value);
        CGFloat offsetX = fabsf(diagonal/cosf(radian));
        CGFloat offsetY = -diagonal/sinf(radian);
        self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, offsetX, offsetY);
    }
    
    
    CGFloat scale = self.scale;
    CGFloat width = scale*CGRectGetWidth(self.initialImageFrame);
    CGFloat height = scale*CGRectGetHeight(self.initialImageFrame);

    NSLog(@"scale = %f", scale);
    
    
    CGPoint bottomRight = self.bottomRight;
    
    if (bottomRight.x > width) {
        CGFloat diagonal = bottomRight.x-topLeft.x-width;
        CGFloat radian = DEGREES_TO_RADIANS(sender.value);
        CGFloat horizontalOffsetX = diagonal/cosf(radian);
        CGFloat horizontalOffsetY = diagonal/sinf(radian);
        
        if (bottomRight.x-topLeft.x > width) {
            
            self.imageView.transform = CGAffineTransformScale(self.imageView.transform, 1/self.imageView.transform.a, 1/self.imageView.transform.a);
            NSLog(@"scale = %f", self.imageView.transform.a);
            self.imageView.transform = CGAffineTransformScale(self.imageView.transform, (self.bottomRight.x-self.topLeft.x)/width, (self.bottomRight.x-self.topLeft.x)/width);
            
            if (self.topLeft.x < 0) {
                CGFloat diagonal = fabsf(self.topLeft.x);
                CGFloat radian = DEGREES_TO_RADIANS(sender.value);
                CGFloat offsetX = -diagonal/cosf(radian);
                self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, offsetX, 0);
            }else {
                CGFloat diagonal = fabsf(self.topLeft.x);
                CGFloat radian = DEGREES_TO_RADIANS(sender.value);
                CGFloat offsetX = -diagonal/cosf(radian);
                self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, -offsetX, 0);
            }
        }else{
            self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, horizontalOffsetX, horizontalOffsetY);
        }

    }

    return;
    //bottomLeft

    CGPoint bottomLeft = self.bottomLeft;

    if (bottomLeft.y > height) {
        

        if (bottomLeft.y-topRight.y > height) {
            self.imageView.transform = CGAffineTransformScale(self.imageView.transform, 1/self.imageView.transform.a, 1/self.imageView.transform.a);
            self.imageView.transform = CGAffineTransformScale(self.imageView.transform, (self.bottomLeft.y-self.topRight.y)/height, (self.bottomLeft.y-self.topRight.y)/height);
            
            if (self.bottomLeft.y > height) {
                CGFloat diagonal = fabsf(self.topLeft.x);
                CGFloat radian = DEGREES_TO_RADIANS(sender.value);
                CGFloat offsetX = -diagonal/sinf(radian);
                self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, offsetX, 0);
            }
        }
        else {
            CGFloat height = self.imageView.transform.a*CGRectGetHeight(self.initialImageFrame);
            NSLog(@"scale = %f", self.imageView.transform.a);
            CGFloat diagonal = fabsf(self.bottomLeft.y-self.topRight.y-height);
            CGFloat radian = DEGREES_TO_RADIANS(sender.value);
            CGFloat offsetX = -diagonal/sinf(radian);
            CGFloat offsetY = diagonal/cosf(radian);
            self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, -offsetX, offsetY);
        }
    }

    
    
//    CGFloat width = _cropView.width*sinf(radian)+_cropView.height*cosf(radian);
//    CGFloat height = _cropView.height*sinf(radian)+_cropView.width*cosf(radian);
    
    
//    self.imageView.size = CGSizeMake(width, height);
//    self.imageView.center = _cropView.center;

}

#pragma mark - Util
////////////////////////////////////////////////////////////////////////////////////////////////////
- (CGFloat) imageRotation
{
    CGAffineTransform t = self.imageView.transform;
    return atan2f(t.b, t.a);
}

- (CGRect)boundingBoxForRect:(CGRect)rect rotatedByRadians:(CGFloat)angle
{
    CGAffineTransform t = CGAffineTransformMakeTranslation(CGRectGetMidX(rect), CGRectGetMidY(rect));
    t = CGAffineTransformRotate(t,angle);
    t = CGAffineTransformTranslate(t,-CGRectGetMidX(rect), -CGRectGetMidY(rect));
    return CGRectApplyAffineTransform(rect, t);
}

- (Rectangle)RectangleFromCGRect:(CGRect)rect
{
    return (Rectangle) {
        .tl = (CGPoint){rect.origin.x, rect.origin.y},
        .tr = (CGPoint){CGRectGetMaxX(rect), rect.origin.y},
        .br = (CGPoint){CGRectGetMaxX(rect), CGRectGetMaxY(rect)},
        .bl = (CGPoint){rect.origin.x, CGRectGetMaxY(rect)}
    };
}

-(CGRect)CGRectFromRectangle:(Rectangle)rect
{
    return (CGRect) {
        .origin = rect.tl,
        .size = (CGSize){.width = rect.tr.x - rect.tl.x, .height = rect.bl.y - rect.tl.y}
    };
}

- (Rectangle)applyTransform:(CGAffineTransform)transform toRect:(CGRect)rect
{
    CGAffineTransform t = CGAffineTransformMakeTranslation(CGRectGetMidX(rect), CGRectGetMidY(rect));
    t = CGAffineTransformConcat(self.imageView.transform, t);
    t = CGAffineTransformTranslate(t,-CGRectGetMidX(rect), -CGRectGetMidY(rect));
    
    Rectangle r = [self RectangleFromCGRect:rect];
    return (Rectangle) {
        .tl = CGPointApplyAffineTransform(r.tl, t),
        .tr = CGPointApplyAffineTransform(r.tr, t),
        .br = CGPointApplyAffineTransform(r.br, t),
        .bl = CGPointApplyAffineTransform(r.bl, t)
    };
}

- (Rectangle)applyTransform:(CGAffineTransform)t toRectangle:(Rectangle)r
{
    return (Rectangle) {
        .tl = CGPointApplyAffineTransform(r.tl, t),
        .tr = CGPointApplyAffineTransform(r.tr, t),
        .br = CGPointApplyAffineTransform(r.br, t),
        .bl = CGPointApplyAffineTransform(r.bl, t)
    };
}

#pragma Touch Event

- (void)handleTouches:(NSSet*)touches
{
    self.touchCenter = CGPointZero;
    if(touches.count < 2) return;
    
    [touches enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        UITouch *touch = (UITouch*)obj;
        CGPoint touchLocation = [touch locationInView:self.imageView];
        self.touchCenter = CGPointMake(self.touchCenter.x + touchLocation.x, self.touchCenter.y +touchLocation.y);
    }];
    self.touchCenter = CGPointMake(self.touchCenter.x/touches.count, self.touchCenter.y/touches.count);
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self handleTouches:[event allTouches]];
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [self handleTouches:[event allTouches]];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self handleTouches:[event allTouches]];
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self handleTouches:[event allTouches]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
