//
//  ViewController.m
//  CLNF-iOS
//
//  Created by Mamunul on 10/17/17.
//  Copyright © 2017 Mamunul. All rights reserved.
//

#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#import "ViewController.h"
#include "CameraResolution.h"
#import "FDFaceDetector.h"
#import "FDFaceFeatures.h"


#include <iostream>
///// user
#include "FaceARDetectIOS.h"

#define QUEUE_NAME_VIDEO "com.ipvision.camera.samplebufferqueue"

@interface ViewController(){
	

	cv::Mat targetImage;
	int frame_count;
	AVCaptureDeviceInput *cameraDeviceInput;
	AVCaptureSession* captureSession;
	AVSampleBufferDisplayLayer* displayLayer;
	FDFaceDetector *faceDetector;
	
	CameraData cameraData;
	
	
}
@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	
	EAGLContext *eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
	NSDictionary *contextSettings = [NSDictionary dictionaryWithObject:[NSNull null]
																forKey:(id)kCIContextWorkingColorSpace];
	CIContext *ciContext = [CIContext contextWithEAGLContext:eaglContext options:contextSettings];
	faceDetector = [[FDFaceDetector alloc] initWithContext:ciContext];
	
	
	cameraData.numberOfPixels = PreviewHeight * PreviewWidth;
	
	
	frame_count = 0;

	
}
-(AVCaptureDevice *)frontFacingCameraIfAvailable
{
	NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	AVCaptureDevice *captureDevice = nil;
	for (AVCaptureDevice *device in videoDevices)
	{
		if (device.position == AVCaptureDevicePositionFront)
		{
			captureDevice = device;
			break;
		}
	}
	
	//  couldn't find one on the front, so just get the default video device.
	if (!captureDevice)
	{
		captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	}
	
	return captureDevice;
}

-(void)viewDidAppear:(BOOL)animated{
	
	[super viewDidAppear:animated];
	
	
	displayLayer = [[AVSampleBufferDisplayLayer alloc] init];
	
	displayLayer.bounds = self.view.bounds;
	displayLayer.frame = self.view.frame;
	displayLayer.backgroundColor = [UIColor blackColor].CGColor;
	displayLayer.position = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
	displayLayer.videoGravity = AVLayerVideoGravityResizeAspect;

	displayLayer.transform = CATransform3DMakeScale(-1, 1, 1);
	
	// Remove from previous view if exists
	[displayLayer removeFromSuperlayer];
	
	[self.view.layer addSublayer:displayLayer];
	
	captureSession = [AVCaptureSession new];
	[captureSession setSessionPreset:AVCaptureSessionPreset1280x720];
	
	// Get our camera device...

	AVCaptureDevice *cameraDevice = [self frontFacingCameraIfAvailable];
	
	NSError *error;
	
	// Initialize our camera device input...
	cameraDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:cameraDevice error:&error];
	
	// Finally, add our camera device input to our capture session.
	if ([captureSession canAddInput:cameraDeviceInput])
	{
		[captureSession addInput:cameraDeviceInput];
	}
	
	// Initialize image output
	AVCaptureVideoDataOutput *output = [AVCaptureVideoDataOutput new];
	
	[output setAlwaysDiscardsLateVideoFrames:YES];
	
	dispatch_queue_t videoDataOutputQueue = dispatch_queue_create("video_data_output_queue", DISPATCH_QUEUE_SERIAL);
	
	[output setSampleBufferDelegate:self queue:videoDataOutputQueue];
	[output setVideoSettings:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange],(id)kCVPixelBufferPixelFormatTypeKey,nil]];
	
	
	if( [captureSession canAddOutput:output])
	{
		[captureSession addOutput:output];
	}
	
	[[output connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
	
	AVCaptureConnection *videoConnection = NULL;
	
	[captureSession beginConfiguration];
	
	for ( AVCaptureConnection *connection in [output connections] )
	{
		for ( AVCaptureInputPort *port in [connection inputPorts] )
		{
			if ( [[port mediaType] isEqual:AVMediaTypeVideo] )
			{
				videoConnection = connection;
	   
			}
		}
	}
	
	if([videoConnection isVideoOrientationSupported])
	{
		[videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
	}
	
	[captureSession commitConfiguration];
	
	[captureSession startRunning];


}

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
	
	CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	
	CVPixelBufferLockBaseAddress(imageBuffer, 0);
	unsigned char* yBuf = (unsigned char*)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
	
	targetImage = cv::Mat(PreviewHeight,PreviewWidth,CV_8UC1,yBuf,0);
	
	float fx, fy, cx, cy;
	cx = 1.0*targetImage.cols / 2.0;
	cy = 1.0*targetImage.rows / 2.0;
	
	fx = 500 * (targetImage.cols / PreviewHeight);
	fy = 500 * (targetImage.rows / PreviewWidth);
	
	fx = (fx + fy) / 2.0;
	fy = fx;
	cv::Rect_<double> bounding_box;
	
	
	cameraData.processedData = imageBuffer;
	
	std::chrono::high_resolution_clock::time_point t1 = std::chrono::high_resolution_clock::now();
	
	NSArray *faceArray = [faceDetector detectFaceInSampleBuffer:cameraData];
	std::chrono::high_resolution_clock::time_point t2 = std::chrono::high_resolution_clock::now();
	
	std::chrono::duration<double,std::milli> d = t2-t1;
	printf("face detection time:%f\n",d.count());
	
	if (faceArray.count > 0) {
		FDFaceFeatures *faceFeature = (FDFaceFeatures*)[faceArray objectAtIndex:0];
		
		const CGRect rect = faceFeature.detectedFaceFeature.bounds;
		const int width = faceFeature.ImageSize.width;
		const int height = faceFeature.ImageSize.height;
		
		// The origin of CIFaceFeature is right-bottom of image and X-axis and Y-axis are leftward and upward
		// respectively. But dlib expects upright image so dlib image origin is left-top and X-axis and Y-axis
		// are rightward and downward respectively. So we transformed CIFaceFeature rectangle to dlib::rectangle
		// before passing for shape prediction.
		bounding_box.width = rect.size.width;
		bounding_box.height = rect.size.height;
		bounding_box.x = width - rect.origin.x - bounding_box.width;
		bounding_box.y = height - rect.origin.y - bounding_box.height;
		
		
		[[[FaceARDetectIOS alloc] init] run_FaceAR:targetImage frame__:frame_count fx__:fx fy__:fy cx__:cx cy__:cy FaceRect:bounding_box];
		
	}

//
//	[[[FaceARDetectIOS alloc] init] run_FaceAR:targetImage frame__:frame_count fx__:fx fy__:fy cx__:cx cy__:cy];

	frame_count = frame_count + 1;
	CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
	[displayLayer enqueueSampleBuffer:sampleBuffer];
	
	
	
}

@end
