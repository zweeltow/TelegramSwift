//
//  libwebp.h
//  libwebp
//
//  Created by Mikhail Filimonov on 19/11/2020.
//

#import <Foundation/Foundation.h>

//! Project version number for libwebp.
FOUNDATION_EXPORT double libwebpVersionNumber;

//! Project version string for libwebp.
FOUNDATION_EXPORT const unsigned char libwebpVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <libwebp/PublicHeader.h>


NSImage * _Nullable  convertFromWebP(NSData *data);

#import <libwebp/WebPImageCoder.h>
