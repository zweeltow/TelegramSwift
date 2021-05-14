// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

#import "MSACAbstractErrorLog.h"

@class MSACException;

/**
 * Handled Error log for managed platforms (such as Xamarin, Unity, Android Dalvik/ART).
 */
@interface MSACHandledErrorLog : MSACLogWithProperties

/**
 * Unique identifier for this error.
 */
@property(nonatomic, copy) NSString *errorId;

/**
 * The exception.
 */
@property(nonatomic) MSACException *exception;

@end
