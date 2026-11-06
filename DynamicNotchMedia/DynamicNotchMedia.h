#import <Foundation/Foundation.h>

FOUNDATION_EXPORT double DynamicNotchMediaVersionNumber;
FOUNDATION_EXPORT const unsigned char DynamicNotchMediaVersionString[];

FOUNDATION_EXPORT
const char * _Nullable dynamic_notch_media_get(void);

FOUNDATION_EXPORT
void dynamic_notch_media_free(
    const char * _Nullable pointer
);
