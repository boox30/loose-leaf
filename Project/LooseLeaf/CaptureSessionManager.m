//
//  CaptureSessionManager.m
//  LooseLeaf
//
//  Created by Adam Wulf on 4/11/14.
//  Copyright (c) 2014 Milestone Made, LLC. All rights reserved.
//


#import "CaptureSessionManager.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "MMRotationManager.h"

@implementation CaptureSessionManager{
    AVCaptureVideoPreviewLayer *previewLayer;
    AVCaptureSession *captureSession;
    AVCaptureStillImageOutput* stillImageOutput;
    AVCaptureDevice* currDevice;
    CALayer* previewLayerHolder;
}

@synthesize captureSession;
@synthesize previewLayer;
@synthesize delegate;

dispatch_queue_t sessionQueue;

+(dispatch_queue_t) sessionQueue{
    if(!sessionQueue){
        sessionQueue = dispatch_queue_create("CaptureSessionManager.session.queue", DISPATCH_QUEUE_SERIAL);
    }
    return sessionQueue;
}

#pragma mark Capture Session Configuration

- (id)initWithPosition:(AVCaptureDevicePosition)preferredPosition{
	if ((self = [super init])) {
		captureSession = [[AVCaptureSession alloc] init];
        captureSession.sessionPreset = AVCaptureSessionPresetMedium;
        
        [captureSession addObserver:self forKeyPath:@"isInterrupted" options:NSKeyValueObservingOptionNew context:nil];
        
        previewLayerHolder = [[CALayer alloc] init];
        
        dispatch_async([CaptureSessionManager sessionQueue], ^{
            stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
            if ([captureSession canAddOutput:stillImageOutput]){
                NSLog(@"adding picture file output");
                [stillImageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
                [captureSession addOutput:stillImageOutput];
            }
            
            [self changeCameraToDevice:[self deviceForPosition:preferredPosition]];

            [captureSession startRunning];
            [self sessionStarted];
        });
	}
	return self;
}

-(void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    if([keyPath isEqualToString:@"isInterrupted"]){
        NSLog(@"interrupted!");
    }else{
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

-(void) sessionStarted{
    dispatch_async(dispatch_get_main_queue(), ^{
        if(previewLayer){
            [previewLayer removeFromSuperlayer];
        }
        previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
        [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
        CGRect layerRect = [previewLayerHolder bounds];
        layerRect.size.width = floorf(layerRect.size.width);
        layerRect.size.height = floorf(layerRect.size.height);
        [previewLayer setBounds:layerRect];
        [previewLayer setPosition:CGPointMake(CGRectGetMidX(layerRect),CGRectGetMidY(layerRect))];
        [previewLayerHolder addSublayer:previewLayer];
    });
    [delegate sessionStarted];
}

#pragma mark - Public Interface

-(void) changeCamera{
    dispatch_async([CaptureSessionManager sessionQueue], ^{
        NSArray* currentInputs = [[self captureSession] inputs];
        AVCaptureDeviceInput* currInput = [currentInputs firstObject];
        if([currentInputs count]){
            // remove if we have one
            [[self captureSession] removeInput:currInput];
        }
        AVCaptureDevice* nextDevice = [self oppositeDeviceFrom:currDevice];
        [self changeCameraToDevice:nextDevice];
    });
}

-(void) changeCameraToDevice:(AVCaptureDevice*)nextDevice{
    if (nextDevice) {
        NSError *error;
        AVCaptureDeviceInput *videoIn = [AVCaptureDeviceInput deviceInputWithDevice:nextDevice error:&error];
        if(!error){
            if ([[self captureSession] canAddInput:videoIn]){
                currDevice = nextDevice;
                [[self captureSession] addInput:videoIn];
                [self.delegate didChangeCameraTo:videoIn.device.position];
            }else{
                NSLog(@"Couldn't create video input");
                currDevice = nil;
            }
        }else{
            NSLog(@"Couldn't create video input");
            currDevice = nil;
        }
    }else{
        NSLog(@"Couldn't create video capture device");
        currDevice = nil;
    }
}


-(void) addPreviewLayerTo:(CALayer*)layer{
    CGRect layerRect = [layer bounds];
	[previewLayerHolder setBounds:layerRect];
	[previewLayerHolder setPosition:CGPointMake(CGRectGetMidX(layerRect),CGRectGetMidY(layerRect))];
	[layer addSublayer:previewLayerHolder];
}

-(NSString*) logImageOrientation:(UIImageOrientation)orient{
    if(orient == UIImageOrientationDown){
        return @"image down";
    }else if(orient == UIImageOrientationLeft){
        return @"image left";
    }else if(orient == UIImageOrientationRight){
        return @"image right";
    }else if(orient == UIImageOrientationUp){
        return @"image up";
    }
    return @"image unknown";
}

-(NSString*) logVideoOrientation:(AVCaptureVideoOrientation)orient{
    if(orient == AVCaptureVideoOrientationPortraitUpsideDown){
        return @"image down";
    }else if(orient == AVCaptureVideoOrientationLandscapeLeft){
        return @"image left";
    }else if(orient == AVCaptureVideoOrientationLandscapeRight){
        return @"image right";
    }else if(orient == AVCaptureVideoOrientationPortrait){
        return @"image up";
    }
    return @"video unknown";
}

-(NSString*) logAssetOrientation:(ALAssetOrientation)orient{
    if(orient == ALAssetOrientationDown){
        return @"image down";
    }else if(orient == ALAssetOrientationLeft){
        return @"image left";
    }else if(orient == ALAssetOrientationRight){
        return @"image right";
    }else if(orient == ALAssetOrientationUp){
        return @"image up";
    }
    return @"video unknown";
}

-(ALAssetOrientation) currentDeviceOrientation{
    UIDeviceOrientation deviceOrientation = [[MMRotationManager sharedInstace] currentDeviceOrientation];
    if(deviceOrientation == UIDeviceOrientationLandscapeLeft){
        NSLog(@"i think i should save left");
        return ALAssetOrientationUp;
    }else if(deviceOrientation == UIDeviceOrientationPortraitUpsideDown){
        NSLog(@"i think i should save upside down");
        return ALAssetOrientationRight;
    }else if(deviceOrientation == UIDeviceOrientationLandscapeRight){
        NSLog(@"i think i should save right");
        return ALAssetOrientationDown;
    }else{
        NSLog(@"i think i should save portrait");
        return ALAssetOrientationRight;
    }
}

-(void) snapPicture{
	dispatch_async([CaptureSessionManager sessionQueue], ^{
		// Update the orientation on the still image output video connection before capturing.
		[[stillImageOutput connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[(AVCaptureVideoPreviewLayer *)[self previewLayer] connection] videoOrientation]];

		// Flash set to Auto for Still Capture
		[CaptureSessionManager setFlashMode:AVCaptureFlashModeAuto forDevice:currDevice];
		
		// Capture a still image.
		[stillImageOutput captureStillImageAsynchronouslyFromConnection:[stillImageOutput connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
			
			if (imageDataSampleBuffer)
			{
				NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
				UIImage *image = [[UIImage alloc] initWithData:imageData];
                
                [delegate didTakePicture:image];
                
                CGSize sizeOfImage = image.size;
                UIImageOrientation orient = image.imageOrientation;
                AVCaptureVideoOrientation captureOrient = [[(AVCaptureVideoPreviewLayer *)[self previewLayer] connection] videoOrientation];
                NSLog(@"gotcha %f,%f %@ %@ %@", sizeOfImage.width, sizeOfImage.height, [self logImageOrientation:orient], [self logVideoOrientation:captureOrient], [self logAssetOrientation:[self currentDeviceOrientation]]);
                
                // rotate the image that we save
				[[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage]
                                                                 orientation:[self currentDeviceOrientation]
                                                             completionBlock:nil];
			}
		}];
	});
}

#pragma mark - Private

-(AVCaptureDevice*) oppositeDeviceFrom:(AVCaptureDevice*)currentDevice{
    AVCaptureDevicePosition preferredPosition = AVCaptureDevicePositionBack;
    switch (currentDevice.position)
    {
        case AVCaptureDevicePositionUnspecified:
            preferredPosition = AVCaptureDevicePositionBack;
            break;
        case AVCaptureDevicePositionBack:
            preferredPosition = AVCaptureDevicePositionFront;
            break;
        case AVCaptureDevicePositionFront:
            preferredPosition = AVCaptureDevicePositionBack;
            break;
    }
    
    return [self deviceForPosition:preferredPosition];
}

-(AVCaptureDevice*) deviceForPosition:(AVCaptureDevicePosition)preferredPosition{
    return [CaptureSessionManager deviceWithMediaType:AVMediaTypeVideo preferringPosition:preferredPosition];
}


+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
	AVCaptureDevice *captureDevice = [devices firstObject];
	
	for (AVCaptureDevice *device in devices)
	{
		if ([device position] == position)
		{
			captureDevice = device;
			break;
		}
	}
	
	return captureDevice;
}

+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device
{
	if ([device hasFlash] && [device isFlashModeSupported:flashMode])
	{
		NSError *error = nil;
		if ([device lockForConfiguration:&error])
		{
			[device setFlashMode:flashMode];
			[device unlockForConfiguration];
		}
		else
		{
			NSLog(@"%@", error);
		}
	}
}

- (void)dealloc {
	[[self captureSession] stopRunning];
    [captureSession removeObserver:self forKeyPath:@"isInterrupted"];
}

@end