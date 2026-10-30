#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface HyMTNative : NSObject
- (void)beginRequest;
- (NSDictionary<NSString *, id> *)load:(NSString *)path;
- (NSDictionary<NSString *, id> *)generateBatch:(NSArray<NSDictionary<NSString *, id> *> *)requests progress:(void (^ _Nullable)(NSInteger completed))progress;
- (void)cancel;
- (void)unload;
+ (NSDictionary<NSString *, id> *)memory;
#if DEBUG
- (NSDictionary<NSString *, id> *)generate:(NSString *)message;
- (NSDictionary<NSString *, id> *)benchmarkContext:(NSInteger)parallel;
- (NSDictionary<NSString *, id> *)benchmarkGenerate:(NSArray<NSString *> *)messages options:(NSDictionary<NSString *, id> *)options;
- (void)cancelAtStageForTesting:(NSString *)stage;
#endif
@end
NS_ASSUME_NONNULL_END
