//
//  ViewController.m
//  GCDDemo
//
//  Created by Kinken_Yuen on 2019/2/23.
//  Copyright © 2019年 kinkenyuen. All rights reserved.
//

//去掉Log时间戳
#define NSLog(FORMAT,...) printf("%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String])

#import "ViewController.h"

@interface ViewController ()
@property(nonatomic,assign) NSUInteger responseA;
@property(nonatomic,assign) NSUInteger responseB;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self dispatchOnce];
//    [NSThread detachNewThreadSelector:@selector(syncMainQueue) toTarget:self withObject:nil];
}

/**
 dispatch_once 一次性代码
 */
- (void)dispatchOnce {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"executable only one.");
    });
}

//模拟网络请求A，假设都请求成功
- (void)semRequestAWithSuccess:(void(^)(int))successBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        if (successBlock) {
            successBlock(50);
        }
    });
}

static int result = 0;

/**
 线程同步
 */
- (void)dispatchSemaphore {
    NSLog(@"current thread:%@",[NSThread currentThread]);
    
    NSLog(@"begin Tag");
    
    //创建信号量，计数为0
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //网络请求A
    [self semRequestAWithSuccess:^(int parameter) {
        result = parameter;
        NSLog(@"parameter:%d---task A finish on thread:%@",parameter, [NSThread currentThread]);
        //请求回调后信号量计数+1
        dispatch_semaphore_signal(semaphore);
    }];
    
    //网络请求B
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //等待信号量计数大于1
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        
        NSLog(@"repsonse:%d---task B finish on thread:%@",result + 50, [NSThread currentThread]);
    });
    
    NSLog(@"end Tag");
}

- (void)dispatchApply {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_apply(10, queue, ^(size_t index) {
        NSLog(@"enumeration %zu",index);
    });
    
    NSLog(@"done");
}

static int value = 100;

/**
 dispatch_barrier_async
 */
- (void)dispatchBarrierAsync {
    NSLog(@"current thread:%@",[NSThread currentThread]);
    
    NSLog(@"begin Tag");
    
    dispatch_queue_t myQueue = dispatch_queue_create("top.barrierAsync.cQueue", 0);
//    dispatch_queue_t myQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(myQueue, ^{
        //模拟读操作
        NSLog(@"read task 1 value %d",value);
        NSLog(@"read task 1 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_async(myQueue, ^{
        //模拟读操作
        NSLog(@"read task 2 value %d",value);
        NSLog(@"read task 2 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_barrier_async(myQueue, ^{
        //模拟写操作
        NSLog(@"write task begin.");
        value +=100;
        NSLog(@"write task end.");
    });
    
    dispatch_async(myQueue, ^{
        //模拟读操作
        NSLog(@"read task 3 value %d",value);
        NSLog(@"read task 3 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_async(myQueue, ^{
        //模拟读操作
        NSLog(@"read task 4 value %d",value);
        NSLog(@"read task 4 finish on thread:%@",[NSThread currentThread]);
    });
}

//模拟网络请求A，假设都请求成功
- (void)requestAWithSuccess:(void(^)(BOOL))successBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        if (successBlock) {
            successBlock(YES);
        }
    });
}

//模拟网络请求B，假设都请求成功
- (void)requestBWithSuccess:(void(^)(BOOL))successBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        if (successBlock) {
            successBlock(YES);
        }
    });
}

/**
 dispatch_group_enter/leave
 */
- (void)dispatchGroupEnterLeave {
    NSLog(@"current thread:%@",[NSThread currentThread]);
    
    NSLog(@"begin Tag");
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t myQueue = dispatch_queue_create("top.groupAsync.cQueue", 0);
//    dispatch_queue_t cQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_group_enter(group);
    dispatch_group_async(group, myQueue, ^{
        //网络请求A
        [self requestAWithSuccess:^(BOOL success) {
            if (success) {
                self.responseA = 50;
                NSLog(@"responserA:%ld---task A finish on thread:%@",self.responseA, [NSThread currentThread]);
                //请求回调后leave group
                dispatch_group_leave(group);
            }
        }];
    });
    
    dispatch_group_enter(group);
    dispatch_group_async(group, myQueue, ^{
        //网络请求B
        [self requestBWithSuccess:^(BOOL success) {
            if (success) {
                self.responseB = 50;
                NSLog(@"responserB:%ld---task B finish on thread:%@",self.responseB,[NSThread currentThread]);
                dispatch_group_leave(group);
            }
        }];
    });
    
    /**
     group内所有异步任务执行完毕后，向主队列追加任务（也就是回调主线程）
     */
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"final result:%ld",self.responseA + self.responseB);
        NSLog(@"all async tasks finish.");
    });
    
    NSLog(@"end Tag");
}

/**
 dispatch_group_wait
 */
- (void)dispatchGroupWait {
    NSLog(@"current thread:%@",[NSThread currentThread]);
    
    NSLog(@"begin Tag");
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t cQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    /**
     创建多个任务，异步方式执行，追加到全局并发队列
     */
    dispatch_group_async(group, cQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 1 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_group_async(group, cQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 2 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_group_async(group, cQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 3 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 1ull * NSEC_PER_SEC);
    
    /**
     阻塞当前线程（主线程）1秒，等待group内所有异步任务执行完毕后，再恢复线程
     */
    long resule = dispatch_group_wait(group, time);
    
    if (resule == 0) {
        NSLog(@"all finish");
    }else {
        NSLog(@"no finish");
    }

    NSLog(@"end Tag");
}

/**
 dispatch_group_notify
 */
- (void)dispatchGroupNotify {
    NSLog(@"current thread:%@",[NSThread currentThread]);
    
    NSLog(@"begin Tag");
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t cQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    /**
     创建多个任务，异步方式执行，追加到全局并发队列
     */
    dispatch_group_async(group, cQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 1 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_group_async(group, cQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 2 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_group_async(group, cQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 3 finish on thread:%@",[NSThread currentThread]);
    });
    
    /**
     group内所有异步任务执行完毕后，向主队列追加任务（也就是回调主线程）
     */
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"all async tasks finish.");
    });
    
    NSLog(@"end Tag");
}

- (void)dispatchAfter {
    NSLog(@"current thread:%@",[NSThread currentThread]);
    
    /**
     第一个参数：dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC))表示获取一个dispatch_time_t类型的值，DISPATCH_TIME_NOW表示从现在的时间算起，NSEC_PER_SEC表示时间单位，这里是秒，有更细的精度，如毫秒NSEC_PER_MSEC
     第二个参数:追加到的队列
     第三个参数：任务
     */
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"done.");
    });
}

/**
 线程通信
 */
- (void)communicatin {
    NSLog(@"current thread:%@",[NSThread currentThread]);
    
    __block int value = 0;
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(queue, ^{
        //子线程异步操作
        [NSThread sleepForTimeInterval:3];
        value = 100;
        NSLog(@"网络请求中，线程:%@",[NSThread currentThread]);
        
        //回调到主线程处理结果
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"网络请求完成,value : %d.",value);
            NSLog(@"current thread:%@",[NSThread currentThread]);
        });
    });
}

/**
 异步执行 & 主队列
 */
- (void)asyncMainQueue {
    NSLog(@"current thread:%@",[NSThread currentThread]);
    
    NSLog(@"begin Tag");
    
    dispatch_queue_t mQueue = dispatch_get_main_queue();
    
    /**
     创建多个任务，异步方式执行，追加到主队列
     */
    dispatch_async(mQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 1 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_async(mQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 2 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_async(mQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 3 finish on thread:%@",[NSThread currentThread]);
    });
    
    NSLog(@"end Tag");
}


/**
 同步执行 & 主队列
 */
- (void)syncMainQueue {
    NSLog(@"current thread:%@",[NSThread currentThread]);
    
    NSLog(@"begin Tag");
    
    dispatch_queue_t mQueue = dispatch_get_main_queue();
    
    /**
     创建多个任务，同步方式执行，追加到主队列
     */
    dispatch_sync(mQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 1 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_sync(mQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 2 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_sync(mQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 3 finish on thread:%@",[NSThread currentThread]);
    });
    
    NSLog(@"end Tag");
}

/**
 同步执行 & 全局并发队列
 */
- (void)syncGlobalConcurrent {
    NSLog(@"current thread:%@",[NSThread currentThread]);
    
    NSLog(@"begin Tag");
    
    dispatch_queue_t gQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    /**
     创建多个任务，同步方式执行，追加到全局并发队列
     */
    dispatch_sync(gQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 1 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_sync(gQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 2 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_sync(gQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 3 finish on thread:%@",[NSThread currentThread]);
    });
    
    NSLog(@"end Tag");
}

/**
 异步任务 & 全局并发队列
 */
- (void)asyncGlobalConcurrent {
    NSLog(@"current thread:%@",[NSThread currentThread]);
    
    NSLog(@"begin Tag");
    
    dispatch_queue_t gQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    /**
     创建多个任务，异步方式执行，追加到全局并发队列
     */
    dispatch_async(gQueue, ^{
        //加个for循环是为了演示并发乱序执行，防止任务过少，效果就像串行执行一样
        for (int i =0 ; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
            NSLog(@"task 1 finish on thread:%@",[NSThread currentThread]);
        }
    });
    
    dispatch_async(gQueue, ^{
        for (int i =0 ; i < 2; i++) {
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 2 finish on thread:%@",[NSThread currentThread]);
        }
    });
    
    dispatch_async(gQueue, ^{
        for (int i =0 ; i < 2; i++) {
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 3 finish on thread:%@",[NSThread currentThread]);
        }
    });
    
    NSLog(@"end Tag");
}

/**
 异步执行 & 并发队列
 */
- (void)asyncConcurrent {
    NSLog(@"current thread:%@",[NSThread currentThread]);
    
    NSLog(@"begin Tag");
    
    dispatch_queue_t cQueue = dispatch_queue_create("top.async.cQueue", DISPATCH_QUEUE_CONCURRENT);
    
    /**
     创建多个任务，异步方式执行，追加到串行队列
     */
    dispatch_async(cQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 1 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_async(cQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 2 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_async(cQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 3 finish on thread:%@",[NSThread currentThread]);
    });
    
    NSLog(@"end Tag");
}

/**
 异步执行 & 串行队列
 */
- (void)asyncSerial {
    NSLog(@"current thread:%@",[NSThread currentThread]);
    
    NSLog(@"begin Tag");

    dispatch_queue_t sQueue = dispatch_queue_create("top.async.sQueue", DISPATCH_QUEUE_SERIAL);
    
    /**
     创建多个任务，异步方式执行，追加到串行队列
     */
    dispatch_async(sQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 1 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_async(sQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 2 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_async(sQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 3 finish on thread:%@",[NSThread currentThread]);
    });
    
    NSLog(@"end Tag");
}

/**
 同步执行 & 并发队列
 */
- (void)syncConcurrent {
    NSLog(@"current thread:%@",[NSThread currentThread]);
    
    NSLog(@"begin Tag");

    dispatch_queue_t cQueue = dispatch_queue_create("top.sync.cQueue", DISPATCH_QUEUE_CONCURRENT);
    
    /**
     创建多个任务，同步方式执行，追加到并发队列
     */
    dispatch_sync(cQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 1 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_sync(cQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 2 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_sync(cQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 3 finish on thread:%@",[NSThread currentThread]);
    });
    
    NSLog(@"end Tag");
}

/**
 同步执行 & 串行队列
 */
- (void)syncSerial {
    NSLog(@"current thread:%@",[NSThread currentThread]);
    
    NSLog(@"begin Tag");
    
    /**
     创建串行队列

     parameter1：队列名称，常用逆序命名，用于调试区分队列
     parameter2：队列类型，可传NULL，表示默认创建串行队列
     */
    dispatch_queue_t sQueue = dispatch_queue_create("top.sync.sQueue", DISPATCH_QUEUE_SERIAL);
    
    /**
     创建多个任务，同步方式执行，追加到串行队列
     */
    dispatch_sync(sQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 1 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_sync(sQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 2 finish on thread:%@",[NSThread currentThread]);
    });
    
    dispatch_sync(sQueue, ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        NSLog(@"task 3 finish on thread:%@",[NSThread currentThread]);
    });
    
    NSLog(@"end Tag");
}


@end
