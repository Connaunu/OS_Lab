# Lab6 report

## [练习0] 填写已有实验

需要改进的函数有：alloc_proc、trap_dispatch。

alloc_proc
```
// alloc_proc - alloc a proc_struct and init all fields of proc_struct
static struct proc_struct *
alloc_proc(void) {
    struct proc_struct *proc = kmalloc(sizeof(struct proc_struct));
    if (proc != NULL) {
        proc->state = PROC_UNINIT;  // 设置进程为未初始化状态
        proc->pid = -1;             // 未初始化的的进程 id 为 -1
        proc->runs = 0;             // 初始化时间片
        proc->kstack = 0;           // 内存栈的地址
        proc->need_resched = 0;     // 不需要重新调度设
        proc->parent = NULL;        // 父节点设为空
        proc->mm = NULL;            // 虚拟内存设为空
        memset(&(proc->context), 0, sizeof(struct context));    // 无切换内容
        proc->tf = NULL;            // 中断栈帧指针置为空
        proc->cr3 = boot_cr3;       // CR3 寄存器，PDT 的基址
        proc->flags = 0;            // 标志位
        memset(proc->name, 0, PROC_NAME_LEN);   // 进程名
        proc->wait_state = 0;
        proc->cptr = proc->optr = proc->yptr = NULL;
        proc->rq = NULL; // 初始化运行队列为空
        list_init(&(proc->run_link)); // 初始化运行队列的指针
        proc->time_slice = 0; // 初始化时间片
        proc->lab6_run_pool.left = proc->lab6_run_pool.right = proc->lab6_run_pool.parent = NULL; //初始化各类指针为空，包括父进程等待
        proc->lab6_stride = 0;//步数初始化 
        proc->lab6_priority = 0;//初始化优先级
    }
    return proc;
}
```

trap_dispatch
```
case IRQ_OFFSET + IRQ_TIMER:
    ++ticks;
    sched_class_proc_tick(current);
    break;
```


## [练习1] 使用 Round Robin 调度算法

### [练习1.1]
**理解并分析sched_class中各个函数指针的用法。**

RR_init 分析
```
static void
RR_init(struct run_queue *rq) {
    // 初始化进程队列
    list_init(&(rq->run_list));
    // 初始进程数为 0
    rq->proc_num = 0;
}
```

RR_enqueue 分析
```
static void
RR_enqueue(struct run_queue *rq, struct proc_struct *proc) {
    assert(list_empty(&(proc->run_link)));
    // 把新进程加到队列末尾
    list_add_before(&(rq->run_list), &(proc->run_link));
    // 如果进程时间片等于 0 或大于时间片限制
    if (proc->time_slice == 0 || proc->time_slice > rq->max_time_slice) {
        proc->time_slice = rq->max_time_slice;
    }
    // 设置进程所属队列
    proc->rq = rq;
    // 就绪进程数加一
    rq->proc_num ++;
}
```

RR_dequeue 分析
```
static void
RR_dequeue(struct run_queue *rq, struct proc_struct *proc) {
    // 进程控制块指针非空并且进程属于该就绪队列中
    assert(!list_empty(&(proc->run_link)) && proc->rq == rq);
    // 将进程从就绪队列中删除
    list_del_init(&(proc->run_link));
    // 就绪进程数减一
    rq->proc_num --;
}
```

RR_pick_next 分析
```
static struct proc_struct *
RR_pick_next(struct run_queue *rq) {
    // 选取就绪队列的首元素
    list_entry_t *le = list_next(&(rq->run_list));
    // 只要还有就绪进程就返回该进程
    if (le != &(rq->run_list)) {
        return le2proc(le, run_link);
    }
    // 否则返回 NULL
    return NULL;
}
```

RR_proc_tick 分析
```
static void
RR_proc_tick(struct run_queue *rq, struct proc_struct *proc) {
    // 还有剩余时间片
    if (proc->time_slice > 0) {
        proc->time_slice --;
    }
    // 时间片已用完
    if (proc->time_slice == 0) {
        // 进程需要重新调度
        proc->need_resched = 1;
    }
}
```

### [练习1.2]
**结合 Round Robin 调度算法描 ucore 的调度执行过程。**

schedule 分析
```
void
schedule(void) {
    bool intr_flag;
    struct proc_struct *next;
    local_intr_save(intr_flag);
    {
        current->need_resched = 0;
        // 如果当前进城就绪，就加入队列中
        if (current->state == PROC_RUNNABLE) {
            sched_class_enqueue(current);
        }
        // 如果找到了下一个就绪进程，就从队列中删除它
        if ((next = sched_class_pick_next()) != NULL) {
            sched_class_dequeue(next);
        }
        // 如果无就绪进程，就运行空闲进程
        if (next == NULL) {
            next = idleproc;
        }
        // 进程被调用次数加一
        next->runs ++;
        if (next != current) {
            // 运行就绪进程（next 或 idle）
            proc_run(next);
        }
    }
    local_intr_restore(intr_flag);
}
```

### [练习1.3]
**简要说明如何设计实现”多级反馈队列调度算法“，给出概要设计。**

> 为了防止优先级较低的进程出现饥饿现象（长时间未被调用），进程选择部分进行了改进。

1. 假设一共 4 个队列。进程在进入待调度的队列等待时，首先进入优先级最高的 Q0 队列等待。
2. 每次根据优先级随机选择一个队列，队列的被选中概率为 1 - (2^k / (2^4 - 1))，k 为进程优先级。如果被选中队列中无就绪进程，则从高优先级队列中依次查找就绪进程。每个队列的时间片为 2^k * 10 ms 。
3. Q0、Q1、Q2 队列使用 FIFO 算法，若时间片用完且未完成，则进入低一级队列。Q3 队列使用 Round Robin 算法。

## [练习2] 实现 Stride Scheduling 调度算法

stride_init 分析
```
static void
stride_init(struct run_queue *rq) {
    // (1) init the ready process list: rq->run_list
    list_init(&(rq->run_list));
    // (2) init the run pool: rq->lab6_run_pool
    rq->lab6_run_pool = NULL;
    // (3) set number of process: rq->proc_num to 0
    rq->proc_num = 0;
}
```

stride_enqueue 分析
```
static void
stride_enqueue(struct run_queue *rq, struct proc_struct *proc) {
    // (1) insert the proc into rq correctly
    rq->lab6_run_pool = skew_heap_insert(rq->lab6_run_pool, &(proc->lab6_run_pool), proc_stride_comp_f);
    // (2) recalculate proc->time_slice
    if (proc->time_slice == 0 || proc->time_slice > rq->max_time_slice) {
        proc->time_slice = rq->max_time_slice;
    }
    // (3) set proc->rq pointer to rq
    proc->rq = rq;
    // (4) increase rq->proc_num
    rq->proc_num ++;
}
```

stride_dequeue 分析
```
static void
stride_dequeue(struct run_queue *rq, struct proc_struct *proc) {
    // (1) remove the proc from rq correctly
    rq->lab6_run_pool = skew_heap_remove(rq->lab6_run_pool, &(proc->lab6_run_pool), proc_stride_comp_f);
    --rq->proc_num;
}
```

stride_pick_next 分析
```
static struct proc_struct *
stride_pick_next(struct run_queue *rq) {
    if (rq->lab6_run_pool == NULL) 
        return NULL;
    // (1) get a  proc_struct pointer p  with the minimum value of stride
    struct proc_struct *p = le2proc(rq->lab6_run_pool, lab6_run_pool);
    unsigned int before = p->lab6_stride;
    // (2) update p;s stride value: p->lab6_stride
    if (p->lab6_priority == 0)
        p->lab6_stride += BIG_STRIDE;
    else 
        p->lab6_stride += BIG_STRIDE / p->lab6_priority; // 只有该比例才是严格线性的，能够通过测试
    // (3) return p
    return p;
}
```

stride_proc_tick 分析
```
static void
stride_proc_tick(struct run_queue *rq, struct proc_struct *proc) {
    if (proc->time_slice > 0) {
        // 剩余时间片减一
        proc->time_slice --;
    }
    // 如果已经没有剩余时间片
    if (proc->time_slice == 0) {
        // 则需要重新调度
        proc->need_resched = 1;
    }
}
```

> 由于 int 长度为 32 位，所以 BIG_STRIDE 取值为 int 范围内的最大整数：0x7FFFFFFF 。

**对于测试用例的理解**

run-priority 运行的文件是priority.c ，程序创建了五个子进程，优先级为 1..5 ，每个程序运行的时间均位 1s ，所以优先级越高，运行次数越少。stride_pick_next 中，只要 **步长** 和 **p->lab6_priority** 负相关即可满足。但是如果需要满足优先级和运行次数成线性关系，则需要：**步长 = BIG_STRIDE / p->lab6_priority** 。
