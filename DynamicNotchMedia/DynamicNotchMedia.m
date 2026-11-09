#import "DynamicNotchMedia.h"

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <CoreFoundation/CoreFoundation.h>

#import <dlfcn.h>
#import <unistd.h>

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

// MARK: - MediaRemote Types

typedef void (*MRGetNowPlayingInfoFunction)(
    dispatch_queue_t queue,
    void (^callback)(CFDictionaryRef _Nullable information)
);

typedef void (*MRGetNowPlayingApplicationPIDFunction)(
    dispatch_queue_t queue,
    void (^callback)(int pid)
);

typedef Boolean (*MRSendCommandFunction)(
    int command,
    CFDictionaryRef _Nullable userInfo
);

typedef void (*MRSetElapsedTimeFunction)(
    double elapsedTime
);

// MARK: - MediaRemote Handle

static void *
mediaRemoteHandle(void) {

    static void *handle = NULL;
    static dispatch_once_t onceToken;

    dispatch_once(
        &onceToken,
        ^{

            const char *frameworkPath =
                "/System/Library/PrivateFrameworks/"
                "MediaRemote.framework/MediaRemote";

            handle =
                dlopen(
                    frameworkPath,
                    RTLD_NOW
                );

            if (handle == NULL) {

                NSLog(
                    @"DynamicNotchMedia: unable to load MediaRemote"
                );
            }
        }
    );

    return handle;
}

// MARK: - Symbols

static MRGetNowPlayingInfoFunction
getNowPlayingInfoFunction(void) {

    static MRGetNowPlayingInfoFunction function = NULL;
    static dispatch_once_t onceToken;

    dispatch_once(
        &onceToken,
        ^{

            void *handle =
                mediaRemoteHandle();

            if (handle == NULL) {
                return;
            }

            function =
                (MRGetNowPlayingInfoFunction)
                dlsym(
                    handle,
                    "MRMediaRemoteGetNowPlayingInfo"
                );

            if (function == NULL) {

                NSLog(
                    @"DynamicNotchMedia: "
                    @"MRMediaRemoteGetNowPlayingInfo not found"
                );
            }
        }
    );

    return function;
}

static MRGetNowPlayingApplicationPIDFunction
getNowPlayingApplicationPIDFunction(void) {

    static MRGetNowPlayingApplicationPIDFunction function = NULL;
    static dispatch_once_t onceToken;

    dispatch_once(
        &onceToken,
        ^{

            void *handle =
                mediaRemoteHandle();

            if (handle == NULL) {
                return;
            }

            function =
                (MRGetNowPlayingApplicationPIDFunction)
                dlsym(
                    handle,
                    "MRMediaRemoteGetNowPlayingApplicationPID"
                );

            if (function == NULL) {

                NSLog(
                    @"DynamicNotchMedia: "
                    @"MRMediaRemoteGetNowPlayingApplicationPID not found"
                );
            }
        }
    );

    return function;
}

static MRSendCommandFunction
sendCommandFunction(void) {

    static MRSendCommandFunction function = NULL;
    static dispatch_once_t onceToken;

    dispatch_once(
        &onceToken,
        ^{

            void *handle =
                mediaRemoteHandle();

            if (handle == NULL) {
                return;
            }

            function =
                (MRSendCommandFunction)
                dlsym(
                    handle,
                    "MRMediaRemoteSendCommand"
                );

            if (function == NULL) {

                NSLog(
                    @"DynamicNotchMedia: "
                    @"MRMediaRemoteSendCommand not found"
                );
            }
        }
    );

    return function;
}

static MRSetElapsedTimeFunction
setElapsedTimeFunction(void) {

    static MRSetElapsedTimeFunction function = NULL;
    static dispatch_once_t onceToken;

    dispatch_once(
        &onceToken,
        ^{

            void *handle =
                mediaRemoteHandle();

            if (handle == NULL) {
                return;
            }

            function =
                (MRSetElapsedTimeFunction)
                dlsym(
                    handle,
                    "MRMediaRemoteSetElapsedTime"
                );

            if (function == NULL) {

                NSLog(
                    @"DynamicNotchMedia: "
                    @"MRMediaRemoteSetElapsedTime not found"
                );
            }
        }
    );

    return function;
}

// MARK: - Fetch Now Playing

static NSDictionary *
fetchNowPlayingInfo(void) {

    MRGetNowPlayingInfoFunction function =
        getNowPlayingInfoFunction();

    if (function == NULL) {
        return nil;
    }

    dispatch_semaphore_t semaphore =
        dispatch_semaphore_create(0);

    __block NSDictionary *information =
        nil;

    function(
        dispatch_get_global_queue(
            QOS_CLASS_USER_INITIATED,
            0
        ),
        ^(CFDictionaryRef info) {

            if (info != NULL) {

                information =
                    [
                        (__bridge NSDictionary *)info
                        copy
                    ];
            }

            dispatch_semaphore_signal(
                semaphore
            );
        }
    );

    long result =
        dispatch_semaphore_wait(
            semaphore,
            dispatch_time(
                DISPATCH_TIME_NOW,
                2 * NSEC_PER_SEC
            )
        );

    if (result != 0) {

        NSLog(
            @"DynamicNotchMedia: Now Playing timeout"
        );

        return nil;
    }

    return information;
}

// MARK: - Current Player

static int
currentNowPlayingPID(void) {

    MRGetNowPlayingApplicationPIDFunction function =
        getNowPlayingApplicationPIDFunction();

    if (function == NULL) {
        return 0;
    }

    dispatch_semaphore_t semaphore =
        dispatch_semaphore_create(0);

    __block int playerPID = 0;

    function(
        dispatch_get_global_queue(
            QOS_CLASS_USER_INITIATED,
            0
        ),
        ^(int pid) {

            playerPID =
                pid;

            dispatch_semaphore_signal(
                semaphore
            );
        }
    );

    long result =
        dispatch_semaphore_wait(
            semaphore,
            dispatch_time(
                DISPATCH_TIME_NOW,
                2 * NSEC_PER_SEC
            )
        );

    if (result != 0) {
        return 0;
    }

    return playerPID;
}

static NSString *
currentNowPlayingBundleIdentifier(void) {

    int pid =
        currentNowPlayingPID();

    if (pid <= 0) {
        return nil;
    }

    NSRunningApplication *application =
        [NSRunningApplication
            runningApplicationWithProcessIdentifier:
                pid
        ];

    if (application == nil) {
        return nil;
    }

    return application.bundleIdentifier;
}

// MARK: - Wait For Command

static void
waitForCommandCompletion(void) {

    MRGetNowPlayingApplicationPIDFunction function =
        getNowPlayingApplicationPIDFunction();

    if (function == NULL) {

        usleep(
            150000
        );

        return;
    }

    dispatch_semaphore_t semaphore =
        dispatch_semaphore_create(0);

    function(
        dispatch_get_global_queue(
            QOS_CLASS_USER_INITIATED,
            0
        ),
        ^(int pid) {

            (void)pid;

            dispatch_semaphore_signal(
                semaphore
            );
        }
    );

    dispatch_semaphore_wait(
        semaphore,
        dispatch_time(
            DISPATCH_TIME_NOW,
            2 * NSEC_PER_SEC
        )
    );
}

// MARK: - Metadata JSON

static NSDictionary *
normalizedMetadataDictionary(
    NSDictionary *raw
) {

    if (raw == nil) {
        return nil;
    }

    NSMutableDictionary *result =
        [NSMutableDictionary dictionary];

    NSString *title =
        raw[
            @"kMRMediaRemoteNowPlayingInfoTitle"
        ];

    NSString *artist =
        raw[
            @"kMRMediaRemoteNowPlayingInfoArtist"
        ];

    NSString *album =
        raw[
            @"kMRMediaRemoteNowPlayingInfoAlbum"
        ];

    NSNumber *duration =
        raw[
            @"kMRMediaRemoteNowPlayingInfoDuration"
        ];

    NSNumber *elapsedTime =
        raw[
            @"kMRMediaRemoteNowPlayingInfoElapsedTime"
        ];

    NSNumber *playbackRate =
        raw[
            @"kMRMediaRemoteNowPlayingInfoPlaybackRate"
        ];

    NSDate *timestamp =
        raw[
            @"kMRMediaRemoteNowPlayingInfoTimestamp"
        ];

    if (title != nil) {

        result[
            @"title"
        ] = title;
    }

    if (artist != nil) {

        result[
            @"artist"
        ] = artist;
    }

    if (album != nil) {

        result[
            @"album"
        ] = album;
    }

    if (duration != nil) {

        result[
            @"duration"
        ] = duration;
    }

    if (elapsedTime != nil) {

        result[
            @"elapsedTime"
        ] = elapsedTime;
    }

    if (playbackRate != nil) {

        result[
            @"playbackRate"
        ] = playbackRate;

        result[
            @"playing"
        ] =
            @(
                playbackRate.doubleValue > 0
            );
    }

    if (timestamp != nil) {

        result[
            @"timestamp"
        ] =
            @(
                timestamp.timeIntervalSince1970
            );
    }

    NSString *bundleIdentifier =
        currentNowPlayingBundleIdentifier();

    result[
        @"bundleIdentifier"
    ] =
        bundleIdentifier != nil
        ? bundleIdentifier
        : @"";

    return result;
}

static NSString *
dynamicNotchGetMetadataJSON(void) {

    NSDictionary *information =
        fetchNowPlayingInfo();

    if (information == nil) {
        return nil;
    }

    NSDictionary *normalized =
        normalizedMetadataDictionary(
            information
        );

    if (normalized == nil) {
        return nil;
    }

    NSError *error =
        nil;

    NSData *jsonData =
        [NSJSONSerialization
            dataWithJSONObject:
                normalized
            options:
                0
            error:
                &error
        ];

    if (
        jsonData == nil
        ||
        error != nil
    ) {

        NSLog(
            @"DynamicNotchMedia metadata JSON error: %@",
            error
        );

        return nil;
    }

    return [
        [NSString alloc]
        initWithData:
            jsonData
        encoding:
            NSUTF8StringEncoding
    ];
}

// MARK: - Artwork JSON

static NSString *
dynamicNotchGetArtworkJSON(void) {

    NSDictionary *raw =
        fetchNowPlayingInfo();

    if (raw == nil) {
        return nil;
    }

    NSMutableDictionary *result =
        [NSMutableDictionary dictionary];

    NSString *title =
        raw[
            @"kMRMediaRemoteNowPlayingInfoTitle"
        ];

    NSString *artist =
        raw[
            @"kMRMediaRemoteNowPlayingInfoArtist"
        ];

    NSString *album =
        raw[
            @"kMRMediaRemoteNowPlayingInfoAlbum"
        ];

    NSNumber *duration =
        raw[
            @"kMRMediaRemoteNowPlayingInfoDuration"
        ];

    NSData *artworkData =
        raw[
            @"kMRMediaRemoteNowPlayingInfoArtworkData"
        ];

    if (title != nil) {

        result[
            @"title"
        ] = title;
    }

    if (artist != nil) {

        result[
            @"artist"
        ] = artist;
    }

    if (album != nil) {

        result[
            @"album"
        ] = album;
    }

    if (duration != nil) {

        result[
            @"duration"
        ] = duration;
    }

    if (
        artworkData != nil
        &&
        [artworkData isKindOfClass:
            [NSData class]
        ]
        &&
        artworkData.length > 0
    ) {

        NSString *base64 =
            [artworkData
                base64EncodedStringWithOptions:
                    0
            ];

        if (base64 != nil) {

            result[
                @"artworkData"
            ] = base64;
        }
    }

    NSError *error =
        nil;

    NSData *jsonData =
        [NSJSONSerialization
            dataWithJSONObject:
                result
            options:
                0
            error:
                &error
        ];

    if (
        jsonData == nil
        ||
        error != nil
    ) {

        NSLog(
            @"DynamicNotchMedia artwork JSON error: %@",
            error
        );

        return nil;
    }

    return [
        [NSString alloc]
        initWithData:
            jsonData
        encoding:
            NSUTF8StringEncoding
    ];
}

// MARK: - Commands

static BOOL
dynamicNotchSendCommand(
    int command
) {

    MRSendCommandFunction function =
        sendCommandFunction();

    if (function == NULL) {
        return NO;
    }

    Boolean result =
        function(
            command,
            NULL
        );

    waitForCommandCompletion();

    return result
        ? YES
        : NO;
}

// MARK: - Seek

static BOOL
dynamicNotchSeek(
    double seconds
) {

    if (seconds < 0) {
        seconds = 0;
    }

    MRSetElapsedTimeFunction function =
        setElapsedTimeFunction();

    if (function == NULL) {

        NSLog(
            @"DynamicNotchMedia: seek unavailable"
        );

        return NO;
    }

    function(
        seconds
    );

    /*
     NON RIMUOVERE.

     Mantiene il processo vivo abbastanza
     a lungo perché MediaRemote inoltri
     davvero il seek al player.
     */

    waitForCommandCompletion();

    return YES;
}

// MARK: - C API

const char *
dynamic_notch_media_get(void) {

    NSString *json =
        dynamicNotchGetMetadataJSON();

    if (json == nil) {
        return NULL;
    }

    return strdup(
        json.UTF8String
    );
}

void
dynamic_notch_media_free(
    const char *pointer
) {

    if (pointer != NULL) {

        free(
            (void *)pointer
        );
    }
}

// MARK: - XS Get Metadata

XS(
    XS_DynamicNotchMedia_get
) {

    dXSARGS;

    if (items != 0) {

        croak(
            "Usage: DynamicNotchMedia::get()"
        );
    }

    NSString *json =
        dynamicNotchGetMetadataJSON();

    if (json == nil) {
        XSRETURN_UNDEF;
    }

    const char *utf8 =
        json.UTF8String;

    if (utf8 == NULL) {
        XSRETURN_UNDEF;
    }

    ST(0) =
        sv_2mortal(
            newSVpv(
                utf8,
                0
            )
        );

    XSRETURN(1);
}

// MARK: - XS Get Artwork

XS(
    XS_DynamicNotchMedia_getArtwork
) {

    dXSARGS;

    if (items != 0) {

        croak(
            "Usage: DynamicNotchMedia::getArtwork()"
        );
    }

    NSString *json =
        dynamicNotchGetArtworkJSON();

    if (json == nil) {
        XSRETURN_UNDEF;
    }

    const char *utf8 =
        json.UTF8String;

    if (utf8 == NULL) {
        XSRETURN_UNDEF;
    }

    ST(0) =
        sv_2mortal(
            newSVpv(
                utf8,
                0
            )
        );

    XSRETURN(1);
}

// MARK: - XS Toggle

XS(
    XS_DynamicNotchMedia_togglePlayback
) {

    dXSARGS;

    if (items != 0) {

        croak(
            "Usage: DynamicNotchMedia::togglePlayback()"
        );
    }

    BOOL success =
        dynamicNotchSendCommand(
            2
        );

    ST(0) =
        sv_2mortal(
            newSViv(
                success
                ? 1
                : 0
            )
        );

    XSRETURN(1);
}

// MARK: - XS Next

XS(
    XS_DynamicNotchMedia_nextTrack
) {

    dXSARGS;

    if (items != 0) {

        croak(
            "Usage: DynamicNotchMedia::nextTrack()"
        );
    }

    BOOL success =
        dynamicNotchSendCommand(
            4
        );

    ST(0) =
        sv_2mortal(
            newSViv(
                success
                ? 1
                : 0
            )
        );

    XSRETURN(1);
}

// MARK: - XS Previous

XS(
    XS_DynamicNotchMedia_previousTrack
) {

    dXSARGS;

    if (items != 0) {

        croak(
            "Usage: DynamicNotchMedia::previousTrack()"
        );
    }

    BOOL success =
        dynamicNotchSendCommand(
            5
        );

    ST(0) =
        sv_2mortal(
            newSViv(
                success
                ? 1
                : 0
            )
        );

    XSRETURN(1);
}

// MARK: - XS Seek

XS(
    XS_DynamicNotchMedia_seek
) {

    dXSARGS;

    if (items != 1) {

        croak(
            "Usage: DynamicNotchMedia::seek(seconds)"
        );
    }

    double seconds =
        SvNV(
            ST(0)
        );

    BOOL success =
        dynamicNotchSeek(
            seconds
        );

    ST(0) =
        sv_2mortal(
            newSViv(
                success
                ? 1
                : 0
            )
        );

    XSRETURN(1);
}

// MARK: - Perl Bootstrap

EXTERN_C
XS(
    boot_DynamicNotchMedia
) {

    dXSARGS;

    (void)items;
    
    char *file =
        __FILE__;

    newXS(
        "DynamicNotchMedia::get",
        XS_DynamicNotchMedia_get,
        file
    );

    newXS(
        "DynamicNotchMedia::getArtwork",
        XS_DynamicNotchMedia_getArtwork,
        file
    );

    newXS(
        "DynamicNotchMedia::togglePlayback",
        XS_DynamicNotchMedia_togglePlayback,
        file
    );

    newXS(
        "DynamicNotchMedia::nextTrack",
        XS_DynamicNotchMedia_nextTrack,
        file
    );

    newXS(
        "DynamicNotchMedia::previousTrack",
        XS_DynamicNotchMedia_previousTrack,
        file
    );

    newXS(
        "DynamicNotchMedia::seek",
        XS_DynamicNotchMedia_seek,
        file
    );

    XSRETURN_YES;
}
