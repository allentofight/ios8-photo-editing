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
@property(nonatomic,assign) CGFloat minumumScale;
@end

@implementation ViewController {
    
    __weak IBOutlet UIView *_cropView;
}

- (void)viewDidLoad {
    [super viewDidLoad];

}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    self.cropRect = _cropView.frame;
    self.imageView.frame = _cropView.frame;


    
    CGPoint topLeft = _cropView.bounds.origin;
    topLeft = [self.imageView convertPoint:topLeft fromView:_cropView];
    
    CGPoint topRight = _cropView.bounds.origin;
    topRight.x += _cropView.bounds.size.width;
    topRight = [self.imageView convertPoint:topRight fromView:_cropView];
    
    CGPoint bottomLeft = _cropView.bounds.origin;
    bottomLeft.y += _cropView.bounds.size.height;
    bottomLeft = [self.imageView convertPoint:bottomLeft fromView:_cropView];
    
    CGPoint bottomRight = _cropView.bounds.origin;
    bottomRight.x += _cropView.bounds.size.width;
    bottomRight.y += _cropView.bounds.size.height;
    bottomRight = [self.imageView convertPoint:bottomRight fromView:_cropView];
    
//    NSLog(@"topLeft = %@", NSStringFromCGPoint(topLeft));
//    NSLog(@"topRight = %@", NSStringFromCGPoint(topRight));
//    NSLog(@"bottomLeft = %@", NSStringFromCGPoint(bottomLeft));
//    NSLog(@"bottomRight = %@", NSStringFromCGPoint(bottomRight));
    
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    panRecognizer.cancelsTouchesInView = NO;
    panRecognizer.delegate = self;
    [self.view addGestureRecognizer:panRecognizer];
    
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
    
    CGFloat radian = M_PI_4;
    CGFloat width = _cropView.width*sinf(radian)+_cropView.height*cosf(radian);
    CGFloat height = _cropView.height*sinf(radian)+_cropView.width*cosf(radian);
    
    
    self.imageView.transform = CGAffineTransformIdentity;
    self.imageView.size = CGSizeMake(220, 260);
    self.imageView.center = CGPointMake(_cropView.centerX+5, _cropView.centerY+25);
    self.initialImageFrame = self.imageView.frame;
    NSLog(@"scale = %f", self.imageView.transform.a);
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
                if(scale != self.scale) {
                    CGFloat deltaX = self.scaleCenter.x-self.imageView.bounds.size.width/2.0;
                    CGFloat deltaY = self.scaleCenter.y-self.imageView.bounds.size.height/2.0;
                    
                    CGAffineTransform transform =  CGAffineTransformTranslate(self.imageView.transform, deltaX, deltaY);
                    transform = CGAffineTransformScale(transform, scale/self.scale , scale/self.scale);
                    transform = CGAffineTransformTranslate(transform, -deltaX, -deltaY);
                    [self checkBoundsWithTransform:transform];
                    self.view.userInteractionEnabled = NO;
                    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                        self.imageView.transform = self.validTransform;
                    } completion:^(BOOL finished) {
                        self.view.userInteractionEnabled = YES;
                        self.scale = scale;
                        self.minimumScale = scale;
                        NSLog(@"scale = %f",scale);
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


#define DEGREES_TO_RADIANS(angle) ((angle) / 180.0 * M_PI)
- (IBAction)valueChanged:(UISlider *)sender {
    
    CGFloat originRadian = DEGREES_TO_RADIANS(sender.value);
    CGFloat radian = fabsf(originRadian);
    
//    CGFloat width = _cropView.width*sinf(radian)+_cropView.height*cosf(radian);
//    CGFloat height = _cropView.height*sinf(radian)+_cropView.width*cosf(radian);
    
    
    self.imageView.transform = CGAffineTransformIdentity;
//    self.imageView.size = CGSizeMake(width, height);
//    self.imageView.center = _cropView.center;
    self.imageView.transform = CGAffineTransformMakeRotation(originRadian);
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
