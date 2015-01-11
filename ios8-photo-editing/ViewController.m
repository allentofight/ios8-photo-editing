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
    
    __weak IBOutlet UILabel *_rotationLbl;
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
    
    self.imageView.size = _cropRect.size;
    self.imageView.height += 20;
    self.imageView.center = _cropView.center;
    self.initialImageFrame = self.imageView.frame;

    self.validTransform = _imageView.transform;
    
    [self.imageView setTranslatesAutoresizingMaskIntoConstraints:YES];
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
        CGPoint translation = [recognizer translationInView:_imageView];
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
//        NSLog(@"valid...");
        return YES;
    }else{
//        NSLog(@"r3 = %@, r1 = %@", NSStringFromCGRect([self CGRectFromRectangle:r3]), NSStringFromCGRect(r1));
//        NSLog(@"invalid...");
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
    NSLog(@"handleGestureState....");
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
    if (sender < 0) {
        sender.value = 0;
    }
    _rotationLbl.text = [NSString stringWithFormat:@"%f", sender.value];
    
    CGFloat originRadian = DEGREES_TO_RADIANS(sender.value-_preRotation);
    _preRotation = sender.value;
    

    self.imageView.transform = CGAffineTransformRotate(self.imageView.transform, originRadian);
    CGFloat radian = fabsf(DEGREES_TO_RADIANS(sender.value));
    if (!radian) {
        radian = 0.1;
    }
    
    CGFloat minWidth = CGRectGetWidth(self.initialImageFrame)*sinf(radian)+CGRectGetWidth(self.initialImageFrame)*cosf(radian);
    
    if (!sender.value) {
        minWidth = CGRectGetWidth(self.initialImageFrame);
    }
    
    CGAffineTransform t = _imageView.transform;
    CGFloat scale = sqrt(t.a * t.a + t.c * t.c);
    CGFloat xScale = minWidth/CGRectGetWidth(self.initialImageFrame);
    
    xScale = MAX(xScale, self.scale);
    
    _imageView.transform = CGAffineTransformScale(_imageView.transform, 1/scale*xScale, 1/scale*xScale);
    self.validTransform = _imageView.transform;

    BOOL isWithin = [self checkBoundsWithTransform:_imageView.transform];
    if (isWithin) return;
    
    //TopLeft
    if (sender.value > 0) {
        {
            //TopLeft
            CGFloat cropTopLeftX = CGRectGetMinX(_rotatedCropRect);
            CGFloat imageViewLeftX = CGRectGetMinX(_rotatedImageViewRect);
            if (cropTopLeftX < imageViewLeftX) {
                CGFloat diagonal = fabsf(imageViewLeftX-cropTopLeftX);
                CGFloat offsetX = -diagonal/cosf(radian);
                self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, offsetX, 0);
            }
        }
        
        {
            //TopRight
            [self checkBoundsWithTransform:_imageView.transform];
            CGFloat cropTopRightY = CGRectGetMinY(_rotatedCropRect);
            CGFloat imageViewTopRightY = CGRectGetMinY(_rotatedImageViewRect);
            
            if (cropTopRightY < imageViewTopRightY) {
                CGFloat diagonal = fabsf(imageViewTopRightY-cropTopRightY);
                CGFloat offsetY = -diagonal/cosf(radian);
                self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, 0, offsetY);
                NSLog(@"rotation > 0 topRight outOfBounds offsetY = %f", offsetY);
            }
        }
        
        {
            //BottomRight
            [self checkBoundsWithTransform:_imageView.transform];
            CGFloat cropBottomRightX = CGRectGetMaxX(_rotatedCropRect);
            CGFloat imageViewBottomRightX = CGRectGetMaxX(_rotatedImageViewRect);
            if (cropBottomRightX > imageViewBottomRightX) {
                CGFloat diagonal = cropBottomRightX-imageViewBottomRightX;
                CGFloat horizontalOffsetX = diagonal/cosf(radian);
                self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, horizontalOffsetX, 0);
            }
        }
        
        {
            //BottomLeft
            [self checkBoundsWithTransform:_imageView.transform];
            CGFloat cropBottomLeftY = CGRectGetMaxY(_rotatedCropRect);
            CGFloat imageViewBottomLeftY = CGRectGetMaxY(_rotatedImageViewRect);
            
            if (cropBottomLeftY > imageViewBottomLeftY) {
                CGFloat diagonal = fabsf(cropBottomLeftY-imageViewBottomLeftY);
                CGFloat offsetY = diagonal/cosf(radian);
                self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, 0, offsetY);
            }

        }
        
    }else{
        
        {
            //TopRight
            CGFloat cropTopRightX = CGRectGetMaxX(_rotatedCropRect);
            CGFloat imageViewTopRightX = CGRectGetMaxX(_rotatedImageViewRect);
            
            if (cropTopRightX > imageViewTopRightX) {
//                NSLog(@"topRight outOfBounds...");
                CGFloat diagonal = cropTopRightX-imageViewTopRightX;
                CGFloat offsetX = diagonal/cosf(radian);
                self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, offsetX, 0);
            }
        }
        
        
        {
            //TopLeft
            [self checkBoundsWithTransform:_imageView.transform];
            CGFloat cropTopLeftY = CGRectGetMinY(_rotatedCropRect);
            CGFloat imageViewLeftY = CGRectGetMinY(_rotatedImageViewRect);
            if (cropTopLeftY < imageViewLeftY) {

                CGFloat diagonal = fabsf(imageViewLeftY-cropTopLeftY);
                CGFloat offsetY = -diagonal/cosf(radian);
                NSLog(@"TopLeft OutOfBounds... offsetY = %f", offsetY);
                self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, 0, offsetY);
            }
        }
        
        {
            //BottomLeft
            [self checkBoundsWithTransform:_imageView.transform];
            CGFloat cropBottomLeftX = CGRectGetMinX(_rotatedCropRect);
            CGFloat imageViewBottomLeftX = CGRectGetMinX(_rotatedImageViewRect);
            if (cropBottomLeftX < imageViewBottomLeftX) {
//                NSLog(@"BottomLeft OutOfBounds...");
                CGFloat diagonal = imageViewBottomLeftX-cropBottomLeftX;
                CGFloat horizontalOffsetX = diagonal/cosf(radian);
                self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, -horizontalOffsetX, 0);
            }
        }
        
        {
            //BottomRight
            [self checkBoundsWithTransform:_imageView.transform];
            CGFloat cropBottomRightY = CGRectGetMaxY(_rotatedCropRect);
            CGFloat imageViewBottomRightY = CGRectGetMaxY(_rotatedImageViewRect);
            
            if (cropBottomRightY > imageViewBottomRightY) {
                CGFloat diagonal = fabsf(cropBottomRightY-imageViewBottomRightY);
                CGFloat offsetY = diagonal/cosf(radian);
                    self.imageView.transform = CGAffineTransformTranslate(self.imageView.transform, 0, offsetY);
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
