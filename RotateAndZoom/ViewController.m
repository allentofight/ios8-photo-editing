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
    
    __weak IBOutlet UIView *_gestureView;
    
//    CGFloat _userScale;         //用户产生的缩放因子
    
    CGFloat _preRotation;
    
    CGRect _rotatedImageViewRect;
    CGRect _rotatedCropRect;
}

- (void)viewDidLoad {
    [super viewDidLoad];

}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    self.cropRect = _cropView.frame;
    
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    panRecognizer.cancelsTouchesInView = NO;
    [panRecognizer setMinimumNumberOfTouches:1];
    [panRecognizer setMaximumNumberOfTouches:1];
    panRecognizer.delegate = self;
    [_gestureView addGestureRecognizer:panRecognizer];
    
    UIPinchGestureRecognizer *pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    pinchRecognizer.cancelsTouchesInView = NO;
    pinchRecognizer.delegate = self;
    [_gestureView addGestureRecognizer:pinchRecognizer];
    
    [self commonInit];
}

- (void)commonInit{
    
    self.scale = 1;
    self.minimumScale = 1;
    self.maximumScale = 5;
    
//    CGFloat radian = M_PI_4;
//    CGFloat width = _cropView.width*sinf(radian)+_cropView.height*cosf(radian);
//    CGFloat height = _cropView.height*sinf(radian)+_cropView.width*cosf(radian);
    
    
    self.imageView.size = _cropRect.size;
    self.imageView.height += 20;
    self.imageView.center = _cropView.center;
    self.initialImageFrame = self.imageView.frame;

}

- (IBAction)reset:(id)sender {
    _slider.value = 0;
    _preRotation = 0;
    self.scale = 1.0;
    self.imageView.transform = CGAffineTransformIdentity;
    self.imageView.frame = self.initialImageFrame;
}


- (IBAction)handlePan:(UIPanGestureRecognizer*)recognizer
{
    if([self handleGestureState:recognizer.state]) {
        CGPoint translation = [recognizer translationInView:_gestureView];
        CGAffineTransform transform = CGAffineTransformTranslate( self.imageView.transform, translation.x, translation.y);
        self.imageView.transform = transform;
        [self checkBoundsWithTransform:transform];
        [recognizer setTranslation:CGPointMake(0, 0) inView:_gestureView];
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
//        self.scale *= recognizer.scale;
        self.imageView.transform = transform;
        
        
        self.scale = sqrt(transform.a * transform.a + transform.c * transform.c);
        
        NSLog(@"self.scale = %f", self.scale);
        recognizer.scale = 1;
        
        [self checkBoundsWithTransform:transform];
    }
}



- (BOOL)checkBoundsWithTransform:(CGAffineTransform)transform
{
    
    _rotatedCropRect = [self boundingBoxForRect:self.cropRect rotatedByRadians:[self imageRotation]];
    
    
    Rectangle r2 = [self applyTransform:transform toRect:self.initialImageFrame];
    
    CGAffineTransform t = CGAffineTransformMakeTranslation(CGRectGetMidX(self.cropRect), CGRectGetMidY(self.cropRect));
    t = CGAffineTransformRotate(t, -[self imageRotation]);
    t = CGAffineTransformTranslate(t, -CGRectGetMidX(self.cropRect), -CGRectGetMidY(self.cropRect));
    
    Rectangle r3 = [self applyTransform:t toRectangle:r2];
    
    _rotatedImageViewRect = [self CGRectFromRectangle:r3];
    
    if(CGRectContainsRect(_rotatedImageViewRect,_rotatedCropRect)) {
        self.validTransform = transform;
        NSLog(@"valid...");
        return YES;
    }else{
//        NSLog(@"r3 = %@, r1 = %@", NSStringFromCGRect([self CGRectFromRectangle:r3]), NSStringFromCGRect(r1));
        return NO;
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
    NSLog(@"ended....");
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

- (CGPoint)bottomRight {
    NSLog(@"bottomRight...");
    CGPoint bottomRight = _cropView.bounds.origin;
    bottomRight.x += _cropView.bounds.size.width;
    bottomRight.y += _cropView.bounds.size.height;
    
    
    bottomRight = [self.imageView convertPoint:bottomRight fromView:_cropView];
    return [_cropView convertPoint:bottomRight toView:self.imageView];

}

#define DEGREES_TO_RADIANS(angle) ((angle) / 180.0 * M_PI)
- (IBAction)valueChanged:(UISlider *)sender {
    CGFloat originRadian = DEGREES_TO_RADIANS(sender.value-_preRotation);
    _preRotation = sender.value;

    self.imageView.transform = CGAffineTransformRotate(self.imageView.transform, originRadian);
    CGFloat radian = fabsf(DEGREES_TO_RADIANS(sender.value));
    
    CGFloat minWidth = CGRectGetWidth(self.initialImageFrame)*sinf(radian)+CGRectGetWidth(self.initialImageFrame)*cosf(radian);
    
    CGAffineTransform t = _imageView.transform;
    CGFloat scale = sqrt(t.a * t.a + t.c * t.c);
    
    CGFloat xScale = minWidth/CGRectGetWidth(self.initialImageFrame);
    
    xScale = MAX(xScale, self.scale);

    _imageView.transform = CGAffineTransformScale(_imageView.transform, 1/scale*xScale, 1/scale*xScale);
    self.validTransform = _imageView.transform;

    BOOL isWithin = [self checkBoundsWithTransform:_imageView.transform];
    if (!isWithin) {
        CGFloat cropTopLeftX = CGRectGetMinX(_rotatedCropRect);
        CGFloat imageViewLeft = CGRectGetMinX(_rotatedImageViewRect);
        
        if (cropTopLeftX < imageViewLeft) {
            CGFloat diagonal = fabsf(imageViewLeft-cropTopLeftX);
            CGFloat radian = DEGREES_TO_RADIANS(sender.value);
            CGFloat offsetX = -diagonal/cosf(radian);
            self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, offsetX, 0);
        }
        
        CGFloat cropTopRightY = CGRectGetMinY(_rotatedCropRect);
        CGFloat imageViewTopRightY = CGRectGetMinY(_rotatedImageViewRect);
        
        if (cropTopRightY < imageViewTopRightY) {
            CGFloat diagonal = fabsf(imageViewTopRightY-cropTopRightY);
            CGFloat offsetY = -diagonal/cosf(radian);
            self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, 0, offsetY);
        }
        
        CGFloat cropBottomRightX = CGRectGetMaxX(_rotatedCropRect);
        CGFloat imageViewBottomRightX = CGRectGetMaxX(_rotatedImageViewRect);
        

        
        [self checkBoundsWithTransform:_imageView.transform];
        cropBottomRightX = CGRectGetMaxX(_rotatedCropRect);
        imageViewBottomRightX = CGRectGetMaxX(_rotatedImageViewRect);
        
        if (cropBottomRightX > imageViewBottomRightX) {
            
            CGFloat cropTopLeftX = CGRectGetMinX(_rotatedCropRect);
            CGFloat imageViewLeft = CGRectGetMinX(_rotatedImageViewRect);
            CGFloat diagonal = cropBottomRightX-imageViewBottomRightX;
            CGFloat radian = DEGREES_TO_RADIANS(sender.value);
            CGFloat horizontalOffsetX = diagonal/cosf(radian);
            CGFloat horizontalOffsetY = diagonal/sinf(radian);
            if (fabs(cropBottomRightX-imageViewBottomRightX) < fabs(cropTopLeftX-imageViewLeft)) {
                self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, horizontalOffsetX, 0);
            }else{
                self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, horizontalOffsetX, horizontalOffsetY);
            }

        }
        

        [self checkBoundsWithTransform:_imageView.transform];
        
        CGFloat cropBottomLeftY = CGRectGetMaxY(_rotatedCropRect);
        CGFloat imageViewBottomLeftY = CGRectGetMaxY(_rotatedImageViewRect);
        
        if (cropBottomLeftY > imageViewBottomLeftY) {

            CGFloat cropTopLeftY = CGRectGetMinY(_rotatedCropRect);
            CGFloat imageViewLeftY = CGRectGetMinY(_rotatedImageViewRect);
            CGFloat diagonal = fabsf(cropBottomLeftY-imageViewBottomLeftY);
            CGFloat radian = DEGREES_TO_RADIANS(sender.value);
            CGFloat offsetX = -diagonal/sinf(radian);
            CGFloat offsetY = diagonal/cosf(radian);
            NSLog(@"offsetY = %f", offsetY);
            if (cropBottomLeftY-imageViewBottomLeftY < cropTopLeftY-imageViewLeftY) {
                NSLog(@"onlyY...");
                self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, 0, offsetY);
            }else{
                NSLog(@"x,y....");
                self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, offsetX, offsetY);
            }
            


        }
    }
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
