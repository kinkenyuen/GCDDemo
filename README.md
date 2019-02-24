# 一、GCD简介
Grand Central Dispatch(GCD)是异步执行任务的技术之一，下面引用自百度百科
>Grand Central Dispatch (GCD)是Apple开发的一个多核编程的较新的解决方法。它主要用于优化应用程序以支持多核处理器以及其他对称多处理系统。它是一个在线程池模式的基础上执行的并行任务。在Mac OS X 10.6雪豹中首次推出，也可在IOS 4及以上版本使用。

使用GCD的好处有：

- 用于CPU多核并行运算

- GCD会自动使用更多的CPU核心

- 自动管理线程声明周期（创建线程、调度任务、销毁线程）

- 开发人员只需编写执行任务，并且添加到对应队列让其执行，不需要手动管理线程

---

# 二、帮助理解的相关概念

- 进程：每一个应用程序在系统中正在运行可以视为一个**进程**，系统会分配给每个进程独立的内存运行

- 线程：是程序执行流的最小单元，是进程中的一个实体，有自己的栈与寄存器，进程内的所有任务都在**线程**中执行，因此每个进程至少需要一个线程（**主线程**），多线程就是进程内开启多条线程，让其中的任务并发或并行执行（视CPU核心而定）。

- iOS App主线程：App一旦运行，默认会开启一条线程,就是主线程，主线程的作用一般是刷新UI、处理UI交互，如点击、拖拽等，如果主线程操作太多，非常耗时，就会造成卡顿线程，所以通常会将耗时操作放在后台线程（子线程）中进行，得到处理结果后，再回到主线程刷新UI

- 多线程作用：在一定意义上实现了进程内的资源共享，提升效率，改善交互，合理利用能够提升硬件的利用率

- 多线程问题：多个线程更新相同的资源导致数据不一致（数据竞争）、线程等待阻塞导致互相等待（死锁）、使用大量线程导致CPU重负荷（上下文切换），同时消耗大量内存（线程是占用内存空进的）

- **同步**：在当前线程按先后顺序依次执行任务，不开启新线程

- **异步**：可以开启多个新线程执行任务，可不按顺序执行

- **队列**：一种数据结构，表示装载任务的队行结构

- **并发**：各个线程上的任务可以同时执行

- **串行**：线程执行只能按先后顺序逐一执行

---

# 二、GCD核心概念
两个核心概念：**任务**和**调度队列**

#### 2.1、**任务**
一系列操作的封装，说白了就是开发中的业务逻辑，在GCD中通过block块封装，执行任务有两种方式：**同步执行（sync）**与**异步执行（async）**，两种执行方式的区别是：

- **是否等待队列中的任务执行结束再开始执行**

- **是否具备开启新线程能力**

**同步执行（sync）**：

- 同步添加任务到指定队列，在添加在前面的同步任务执行结束之前，会一直等待，直到前面的任务完成之后再继续执行

- 只在当前线程执行任务，不具备开启新线程能力

**异步执行（async）**：

- 异步添加任务到指定队列，在队列中不等待其他任务执行结束，就可以执行任务

- 可以在新的线程中执行任务，具备开启新线程的能力（**但不一定开启，与任务添加到的队列类型有关**）

#### 2.2、**调度队列（Dispatch Queue）**
指用来存放任务的队列，是一种特殊线性表，采取FIFO（先进先出）原则，新添加的任务放在队列末尾，而读取任务的时候从队列的头部开始。

GCD中有两种队列：**串行队列**、**并发队列**（均遵循FIFO原则），两种队列的区别是：

- 任务执行顺序不同

- 开启线程数不同

**串行队列（Serial Dispatch Queue）**

- 每次只有一个任务执行，任务一个接一个执行

- 只开启一个线程

![1](https://raw.githubusercontent.com/kinkenyuen/kinkenyuen.github.io/master/img/2019-02-23/1.png)

---

**并发队列**

- 多个任务可以并发（同时）执行

- 可以开启多个线程

![2](https://raw.githubusercontent.com/kinkenyuen/kinkenyuen.github.io/master/img/2019-02-23/2.png)

---

>**注意**：**并发队列**的并发功能只在**任务**是**异步执行**方式下才有效

实际上，除了这两种调度队列，还有两种，它们是系统提供的**主队列(Main Dispathch Queue)**、**全局并发队列(Global Dispatch Queue)**

**主队列**：它是主线程中执行的调度队列，因为主线程只有1个，所以主队列是**串行队列**，追加到主队列中的任务是在主线程的**RunLoop**中执行，因此常有用户界面的更新任务会追加到主队列执行。

**全局并发队列**：它是一种所有应用程序都能使用的**并发队列**，该队列有4个优先级，分别是高优先级、默认优先级、低优先级、后台优先级

# 三、GCD基本使用
使用步骤简单分为两步：

1. 创建/获取调度队列（**串行队列(Serial Dispatch Queue)**或**串行队列（Serial Dispatch Queue）**）

2. 指定任务执行方式，追加任务到调度队列，编写任务，剩下的交给系统

下面逐一分析**任务**在**不同执行方式**、**调度队列**的组合情况，加深理解

#### 3.1、**同步执行** & **串行队列**

```
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
```

输出如下

```
current thread:<NSThread: 0x600002b52940>{number = 1, name = main}
begin Tag
task 1 finish on thread:<NSThread: 0x600002b52940>{number = 1, name = main}
task 2 finish on thread:<NSThread: 0x600002b52940>{number = 1, name = main}
task 3 finish on thread:<NSThread: 0x600002b52940>{number = 1, name = main}
end Tag
```

综合上一章理论描述，**同步执行** & **串行队列**不会开启新线程，在当前线程（主线程）执行任务，任务按顺序执行

#### 3.2、**同步执行** & **并发队列**

```
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
```

输出如下

```
current thread:<NSThread: 0x600002fe2900>{number = 1, name = main}
begin Tag
task 1 finish on thread:<NSThread: 0x600002fe2900>{number = 1, name = main}
task 2 finish on thread:<NSThread: 0x600002fe2900>{number = 1, name = main}
task 3 finish on thread:<NSThread: 0x600002fe2900>{number = 1, name = main}
end Tag
```

从输出日志中看到：

- 所有任务都在当前线程（主线程）执行，没有开启新的线程（印证了任务**同步执行**的方式不具备开启新线程的能力）

- 所有任务的执行在`"begin Tag"`与`"end Tag"`之间，（同步执行的任务需要等待队列的任务执行结束），也就是`"end Tag"`会等待所有同步任务执行完再执行，执行流程图可简单抽象成如下：

![3](https://raw.githubusercontent.com/kinkenyuen/kinkenyuen.github.io/master/img/2019-02-23/3.png)

---

主队列上的方法调用，首先在主线程打印`"begin Tag"`，接着向并发队列追加同步任务，因同步执行的任务需要等待队列的任务执行结束（**也就是执行任务2之前需要任务1出队列并在主线程执行结束**），所以紧接着打印`task 1`、`task 2`、`task 3`,最后所有同步任务结束，打印`end Tag`

- 虽然**并发队列**可以开启多个线程并同时执行多个任务，但是此处任务本身需要**同步执行**（不具备开启新线程的能力），这一点对应上了上面**并发队列**提到的**注意点**。因此只能使用当前存在的线程（也就是主线程）,不存在并发，而且当前线程只有等待当前队列中正在执行的任务执行完毕之后，才能继续接着执行下面的操作

#### 3.3、**异步执行** & **串行队列**

```
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
```

输出如下

```
begin Tag
end Tag
task 1 finish on thread:<NSThread: 0x600002d92940>{number = 3, name = (null)}
task 2 finish on thread:<NSThread: 0x600002d92940>{number = 3, name = (null)}
task 3 finish on thread:<NSThread: 0x600002d92940>{number = 3, name = (null)}
```

从输出日志中看到：

- 所有任务打印在`"end Tag"`之后，印证了异步执行的任务在队列中不等待其他任务执行结束，就可以执行任务（可以理解为，只是先追加异步任务到串行队列，不阻塞接下来的代码执行，系统在接下来的某个时刻开启子线程处理串行队列的任务）

- 由于任务是**异步执行**的方式，因此具备开启新线程能力，又由于串行队列里的任务一个接一个执行，因此系统只需要开启一条子线程，让所有异步任务按顺序执行即可

#### 3.4、**异步执行** & **并发队列**

```
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
```

输出如下

```
current thread:<NSThread: 0x60000391e900>{number = 1, name = main}
begin Tag
end Tag
task 2 finish on thread:<NSThread: 0x60000394b9c0>{number = 3, name = (null)}
task 1 finish on thread:<NSThread: 0x60000394d8c0>{number = 4, name = (null)}
task 3 finish on thread:<NSThread: 0x600003958e40>{number = 5, name = (null)}
```

从输出日志看出:

- 所有任务打印在`"end Tag"`后，原因与上一节的输出日志分析第一点相同

- 所有任务的执行顺序并不确定，原因是**并发队列**可以多个任务并发（同时）执行，而且任务执行方式为**异步执行**，具备开启新线程能力，因此系统开启了多个（此处为3个）线程处理这些异步任务

#### 3.5、**同步执行** & **主队列**

```
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
```

运行上面的`syncMainQueue`方法时，会在第一个同步任务出现异常，这种组合出现的异常其实是一种**死锁**

原因：我们在主线程中执行`syncMainQueue`方法，相当于把一个同步任务放到主队列中，而同步执行会等待当前队列中的任务执行完毕，才会执行，追加的同步任务`task 1`等待`syncMainQueue `任务的完成，而`syncMainQueue `方法又会等待`task 1`执行结束后才会继续往下执行，因此造成相互等待，**死锁**

![4](https://raw.githubusercontent.com/kinkenyuen/kinkenyuen.github.io/master/img/2019-02-23/4.png)

---

解决方法：将`syncMainQueue `方法放到子线程执行，这样不会妨碍任务1、2、3在主队列上调度执行

```
[NSThread detachNewThreadSelector:@selector(syncMainQueue) toTarget:self withObject:nil];

```

输出如下

```
current thread:<NSThread: 0x600001c2e5c0>{number = 3, name = (null)}
begin Tag
task 1 finish on thread:<NSThread: 0x600001c7a900>{number = 1, name = main}
task 2 finish on thread:<NSThread: 0x600001c7a900>{number = 1, name = main}
task 3 finish on thread:<NSThread: 0x600001c7a900>{number = 1, name = main}
end Tag
```

#### 3.6、**异步执行** & **主队列**

```
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
```

输出如下

```
current thread:<NSThread: 0x600001df4dc0>{number = 1, name = main}
begin Tag
end Tag
task 1 finish on thread:<NSThread: 0x600001df4dc0>{number = 1, name = main}
task 2 finish on thread:<NSThread: 0x600001df4dc0>{number = 1, name = main}
task 3 finish on thread:<NSThread: 0x600001df4dc0>{number = 1, name = main}
```

从输入日志中看到:

- 所有任务都在当前线程（主线程）中执行，并没有开启新的线程，即使**异步执行**具备开启线程的能力，但因为是主队列，主队列调度的任务均在主线程上执行

- 所有任务打印在`"end Tag"`之后（异步执行不会做任何等待，可以继续执行任务）

- 任务是按顺序执行的（因为主队列是串行队列，每次只有一个任务被执行，任务一个接一个按顺序执行）

---

这里省略**同步执行**、**异步执行**与**全局并发队列**的组合情况，因为这与**同步执行**、**异步执行**与**并发队列**的组合情况一样

#### 3.7、小结

根据上述理论知识描述与源代码实践验证，可得出以下结论

任务执行方式 | 串行队列 | 并发队列 | 主队列 |
---|---|---|---|
同步执行(sync)|没有开启新线程，串行执行任务|没有开启新线程，串行执行任务|主线程调用：死锁        非主线程调用：没有开启新线程，串行执行任务|
异步执行(async)|开启1个子线程，串行执行任务|开启多个线程，并发执行任务|没有开启新线程，串行执行任务|


# 四、GCD线程间通信
一个常见的例子是我们通常把一些耗时的操作放在非主线程，如图片下载、文件上传、网络请求等耗时操作，而当这些耗时操作完成后，需要回到主线程处理这些操作结果，这样就用到了线程通信

```
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
```

输出如下

```
current thread:<NSThread: 0x600003579400>{number = 1, name = main}
网络请求中，线程:<NSThread: 0x60000353ea00>{number = 3, name = (null)}
网络请求完成,value : 100.
current thread:<NSThread: 0x600003579400>{number = 1, name = main}
```

# 五、GCD的一些方法
#### 5.1、dispatch_after

延时执行，经过**指定时间**后追加任务到队列执行，严格来说，这个时间并不是绝对准确，因为追加到队列后，系统还要根据系统状态调度任务，但大致上是非常接近的

```
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
```

输出如下

```
2019-02-24 09:55:11.197798+0800 GCDDemo[1556:24591] current thread:<NSThread: 0x600002ba6e80>{number = 1, name = main}
2019-02-24 09:55:14.198030+0800 GCDDemo[1556:24591] done.
```

#### 5.2、dispatch_group

假设有这样的场景：多个异步执行的耗时操作全部执行结束后，再执行结果处理，用第四章的方法已经解决不了，而`dispatch_group `可以应对

**5.2.1 dispatch_group_notify**

```
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
```

输出如下

```
current thread:<NSThread: 0x600003de2900>{number = 1, name = main}
begin Tag
end Tag
task 1 finish on thread:<NSThread: 0x600003daec00>{number = 3, name = (null)}
task 2 finish on thread:<NSThread: 0x600003da0640>{number = 5, name = (null)}
task 3 finish on thread:<NSThread: 0x600003db2780>{number = 4, name = (null)}
all async tasks finish.
```

可以看到追加到全局并发队列的3个任务执行完毕之后，才会执行主队列的任务(`dispatch_group_notify`追加的block任务)

**5.2.2 dispatch_group_wait**

该函数与`dispatch_group_notify `十分相似，它的效果是可以**阻塞线程**等待全部任务执行结束后再继续往下执行

```
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
    
    /**
     阻塞当前线程（主线程），等待group内所有异步任务执行完毕后，再恢复线程
     */
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    NSLog(@"end Tag");
}
```

输出如下

```
current thread:<NSThread: 0x600001175340>{number = 1, name = main}
begin Tag
task 2 finish on thread:<NSThread: 0x600001120780>{number = 7, name = (null)}
task 1 finish on thread:<NSThread: 0x60000112e680>{number = 6, name = (null)}
task 3 finish on thread:<NSThread: 0x60000112ddc0>{number = 8, name = (null)}
end Tag
```

关于`dispatch_group_wait`函数的第二个参数，该参数指定**等待的时间**，以上例子使用`DISPATCH_TIME_FOREVER `，意味着永久等待，只要异步任务未执行完成，就会一直等待（阻塞主线程），如果指定为`dispatch_time_t`类型，则超过该时间后，就会恢复当前线程，同时`dispatch_group_wait`函数也会返回一个`long`值表示所有任务是否已经执行完毕，其中**返回0表示已经全部完成**，否则返回非0.

```
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
```

输出如下

```
current thread:<NSThread: 0x6000001bcbc0>{number = 1, name = main}
begin Tag
no finish
end Tag
task 1 finish on thread:<NSThread: 0x6000001fb200>{number = 3, name = (null)}
task 2 finish on thread:<NSThread: 0x6000001f4d00>{number = 5, name = (null)}
task 3 finish on thread:<NSThread: 0x6000001f0440>{number = 4, name = (null)}
```

**5.2.2 dispatch_group_enter、dispatch_group_leave**

假设有这样的场景：需要执行多个网络请求，得到多个请求结果，再用这些结果做一些操作。举个例子，现有两个网络请求A与B，我们知道网络请求都是异步执行的,单纯用`dispatch_group_notify `已经无法确保顺序，请求结果还没回调，就往下继续执行了代码。如下使用`dispatch_group_enter `与`dispatch_group_leave `应对

```
//模拟网络请求A，假设都请求成功
- (void)requestAWithSuccess:(void(^)(BOOL success))successBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        if (successBlock) {
            successBlock(YES);
        }
    });
}

//模拟网络请求B，假设都请求成功
- (void)requestBWithSuccess:(void(^)(BOOL success))successBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:2];//模拟任务耗时操作
        if (successBlock) {
            successBlock(YES);
        }
    });
}

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
```

输出如下

```
current thread:<NSThread: 0x600001089400>{number = 1, name = main}
begin Tag
end Tag
responserA:50---task A finish on thread:<NSThread: 0x6000010da040>{number = 5, name = (null)}
responserB:50---task B finish on thread:<NSThread: 0x6000010d9a00>{number = 4, name = (null)}
final result:100
all async tasks finish.
```

这里我用两个`NSUInteger`类型的response属性做标记，请求A回调后做一次赋值操作，请求B回调后做一次赋值操作，最后两个请求完成后相加两值查看是否到达期望效果。

从输出结果可以看出，`dispatch_group_notify`函数的调用是在所有任务里的网络请求回调完成之后执行，原理不是很复杂，在添加`dispatch_group_async`异步任务时，先用`dispatch_group_enter(group);`标记，等到网络请求回调成功之后才手动`dispatch_group_leave(group);`让异步任务出队列，因此只有当所有网络请求回调完成之后，调度组里的队列才为空，最后通过`dispatch_group_notify`通知

#### 5.3、dispatch_barrier_async

主要解决多线程数据写入处理的数据竞争问题以及读写数据产生的不一致问题，也就是资源竞争问题

>注意:该函数必须同`dispatch_queue_create`创建的**并发队列**配合使用,使用**全局并发队列**会无效，读者可尝试

```
- (void)dispatchBarrierAsync {
    NSLog(@"current thread:%@",[NSThread currentThread]);
    
    NSLog(@"begin Tag");
    
    dispatch_queue_t myQueue = dispatch_queue_create("top.barrierAsync.cQueue", 0);
    
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
```

输出如下

```
current thread:<NSThread: 0x600002b15400>{number = 1, name = main}
begin Tag
read task 1 value 100
read task 1 finish on thread:<NSThread: 0x600002b49a40>{number = 3, name = (null)}
read task 2 value 100
read task 2 finish on thread:<NSThread: 0x600002b49a40>{number = 3, name = (null)}
write task begin.
write task end.
read task 3 value 200
read task 3 finish on thread:<NSThread: 0x600002b49a40>{number = 3, name = (null)}
read task 4 value 200
read task 4 finish on thread:<NSThread: 0x600002b49a40>{number = 3, name = (null)}
```

#### 5.4、dispatch_apply

该函数按指定的次数将指定的block任务追加到指定的调度队列，并等待全部处理结束。用于快速迭代（多线程并发遍历）

```
- (void)dispatchApply {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_apply(10, queue, ^(size_t index) {
        NSLog(@"enumeration %zu",index);
    });
    
    NSLog(@"done");
}
```

输出如下


```
enumeration 0
enumeration 1
enumeration 2
enumeration 3
enumeration 4
enumeration 5
enumeration 6
enumeration 7
enumeration 8
enumeration 9
done
```

#### 5.5、Dispatch Semaphore

基于此dispatch_semaphore主要应用于两个方面 ：

1. **保持线程同步**

2. **为线程加锁**

假设有这样的场景：异步执行多个网络请求，请求之间有关联（线程同步问题），举个例子，现有两个网络请求A与B，B的请求参数需要依赖请求A的请求结果.换句话说就是将异步执行任务转换为**“同步执行任务“**

可能会有这样的疑问：为什么不直接在A请求的回调里直接发起B请求?

试想如果请求多了，需要些许多嵌套，降低代码阅读性

下面是使用`Semaphore `信号量的一个例子

```
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
```

输出如下

```
current thread:<NSThread: 0x600003a4d400>{number = 1, name = main}
begin Tag
end Tag
parameter:50---task A finish on thread:<NSThread: 0x600003a1d980>{number = 5, name = (null)}
repsonse:100---task B finish on thread:<NSThread: 0x600003a10d40>{number = 6, name = (null)}
```

从结果可以看出，可以确保请求A的回调结果用于请求B

---

除此之外，`Semaphore`也可以用于并发写数据时的排他控制来达到线程同步（线程安全）效果，这里就不赘述

#### 5.5、dispatch_once

保证在应用程序中只执行一次，常用于单例、`method swizzle`

```
- (void)dispatchOnce {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"executable only one.");
    });
}
```

# 六、小结

看博客看书实践后，笔记写下来的感觉有助于梳理思路；单纯看前辈的博客，总是差了点什么东西，大概就是这个吧...


# 七、参考

- [iOS 多线程：『GCD』详尽总结](https://www.jianshu.com/p/2d57c72016c6)

- [关于iOS多线程，这边勉强可以看看(OC&Swift)](https://www.jianshu.com/p/186f5cdbf4a4)

- 《Objective-C高级编程》
