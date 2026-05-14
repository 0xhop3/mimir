#set page("a4")
#set text(
  size: 10pt,
  font: "TX-02",
  weight: "medium",
  stretch: 75%,
)

= QNX Architecture
== PROCNTO
- It contains 2 components
  1. Neutrino - Microkernel
    - reached by function calls (kernel calls)
    - handles threads and IPC.
  2. Process Manager
    - reached by messages and has threads to handle messages.
    - primarily handles process and memory.
- Tightly bound together and share the same memory address.
- Process ID -> 1 (means first thing to initialize in QNX system).
- *TRADE OFFs*
  - +ve
    1. Reliability and Resilience
    2. ease of configuration and reconfiguration
    3. ease of development
    4. Scalability
  - -ve
    1. System Overhead
    2. more context switches
    3. more copies of data

== PROCESS
- program that loads in memory.
- identified by the `pid`
- owns resources, e.g.
  - memory + code + data
  - open files
  - timers
- security context:
  - identify: user id, group id
  - type id and abilities
- Resources owned by one process are protected from other processes.

== THREADS
- a thread is a single flow of execution or control.
- identified by a thread id `tid`
  - Thread ids are process local.
- thread attributes, e.g.
  - priority
  - scheduling algorithm
  - register set
  - CPU mask for multicore
  - signal mask
- all its attributes have to do with running code.

== PROCESSES AND THREADS
- A process must have at least one thread.
- Threads in a process share all the process resources.
- Threads run code, processes own resources.
- Processes are the building blocks components of a system
  - Visible to each other
  - Communicate with each other
- Threads are hidden details of an implementation
  - Hidden inside a process.

= QNX - MICROKERNEL
- is primarily externally driven
  - maintains the of state of kernel objects such as threads.
  - updates the state based on kernel calls, interrupts, and faults.
- but also has 3 microkernel threads per CPU core:
  - an interrupt service thread (IST) for interprocessor interrupts (IPIs)
  - an IST for timer interrupts
  - an idle thread for when no other thread needs to run
  - Kernel Components:
    1. Synchronization
    2. Scheduler
    3. Threading
    4. Time
    5. Faults
    6. IPC
    7. Interrupt Redirector
- Forms of IPC
  1. Messages: exchange info b/w processes.
  2. Pulses: notification to processes.
  3. Signals: interrupting a process and making it do something different.
  4. POSIX message queues: queued data delivery between processes.
- Threads functions:
  - create /destroy
  - wait
  - change thread attributes
- Thread Sync methods:
  1. mutex -> mutually exclude threads
  2. condvar -> wait for a change
  3. semaphore -> wait for a counter
  4. Barrier -> wait for number of threads
  5. rwlock -> read / write locks
- Time Handling:
  1. Time of the day -> by hardware `ClockCycle()`
  2. Timers -> notify after certain time has passed (core local timer hardware)
- Interrupts
  - all hardware interrupts are vectored to the kernel.
  - a thread can either:
    1. register itself as an IST
    2. request for notification using an event (an in-kernal IST will be provided)
  - The threads run based on priority, scheduling algorithms.
- The Microkernel
  - runs if invoked by:
    - a kernel call
    - an interrupt
    - a processor fault/exception
  - has dedicated threads for handling:
    - interprocessor interrupts (IPIs)
    - clock interrupts
    - idle
  - the microkernel runs on the cores:
    - where a kernel call was made
    - where an interrupt was directed
    - where a fault happened
== SCHEDULING
- Thread states:
  1. blocked
    - waiting for something to happen
    - there are lots of different blocked states depending on what they are waiting for, e.g.
      - *REPLY* -> blocked is waiting for a IPC reply
      - *MUTEX* -> blocked is waiting for a mutex
      - *RECEIVE* -> blocked is waiting to get a message
  2. runnable
    - capable of using the CPU
    - 2 main runnable states
      - *RUNNING* actually using the CPU
      - *READY* waiting while someone else is running
  - Dead thread can never be run again.
- Priority
  - the priority range from 0 - 255
    - 255 -> reserved for the IPI ISTs
    - 254 -> reserved for other in-kernel ISTs
    - 0 -> reserved for idle threads
  - QNX schedules runnable threads:
    - Priority matters for runnable threads only
    - processes are not considered
  - scheduling is preemptive:
    - A higher priority threads runs instead of a lower one
    - not "fair share" or table-driven scheduling
  - Most threads spend most of their time blocked
    - That is how CPU is shared between threads.

== MULTICORE
- means a system that has more that one processor/CPU tight coupled
  - independent processors
  - shared hardware RAM, bus, etc
  - some processor may be "closer" to some processors than others
    - e.g. seperate L1 and L2 cache, but shared L3 cache
- Symmetrical Multiprocessor
  - a special case of multiprocessors are the same
  - used in naming the kernel
  - by default QNX treats multicore systems as SMP systems.
- QNX needs to schedule threads:
  - quickly and effectivelly
    - maximum cost is fixed
  - across multiple cores
  - based on priority and waiting time
- A global shared queue of ready threads may have search problems to find a thread that can run on particular core:
  - worst case is the number of threads
- A per-core ready queues design doesn't distribute load across cores well.
- QNX Solution: cluster-based scheduling

== CLUSTER
- set of related CPU cores
- Used to specify where the thread is allowed to run
  - Thread is only allowed to member of one cluster
- Where a list of *READY* threads is tracked
  - *READY* list are per cluster
- Defined by the startup code in the BSP.
  - Fixed while the system is running
- There are always at least 2 sets of cluster
  - A cluster that represents all the CPU cores
  - A cluster for each core that includes only that CPU core.
  - Every core is always a member of at least 2 clusters
    - The all-cores cluster, and its individual cluster.
- *Startup*
  - cluster must be unique
  - a particular core may be a member of maximum of 8 clusters.
    - every core is, always a member of at least 2 clusters
  - this may be built into the startup
  - or the -c command line option may be used, e.g.:
  - `startup-boardname -c cluster0: 0x7, cluster1: 0x9`
    - this defines 2 new cluster
      - One of which core 0, 1 and 2 (`0x7` is 0...0111 binary, with each bit represent a core)
      - And the other contains core 0 and 3.
      - the names are mandatory, but informational only
      - `pidin syspage=cluster` will display any additional cluster configured
== THREADS AND CORES
- Threads are the scheduled entity:
  - a RUNNING thread is running on particular core
  - a READY thread is ready on a particular cluster:
    - ordered by priority and a timestamp (in `ClockCycles()`)
  - that is, the cluster contains a list of ready *READY* threads
- Scheduling is core-based
  - all scheduling changes are done on the core doing the changes
  - the scheduling code may issue an InterProcessor Interrupt (IPI) to another core if appropriate
- when a thread leaves the RUNNING state:
  - usually this is self-triggered by an IPI from another core
  - could be triggered by an IPI from another core
    - e.g. a thread on another core stopped this thread's process
  - the scheduling core looks at each cluster that it is a member of
    - at least one is guaranteed to have a *READY* thread (the idle thread)
  - it chooses the highest priority *READY* thread from those clusters
    - if there are multiple highest priority, it chooses the one with the lowest timestamp value, the "most eligible" thread
  - the chosen thread becomes *RUNNING* on this core
- On a core, when a thread becomes runnable:
  - usually this is because another thread on the core has unblocked it
  - if the thread is not the most eligible thread on its cluster's *READY* list, no scheduling is needed
    - again, "most eligible" is highest priority, and lowest timestamp
  - if the thread can preempt on the current core, it preempts
  - else if there is an idle core in the thread's cluster, IPI that core
  - else if it can preempt on another core in its cluster, IPI that core
  - else it is added to the *READY* list for its cluster
- *Core Affinity* -> change the cluster that thread belongs to using -> `ThreadCtl(_NTO_TCTL_RUNMASK, void( *) runmask);`
  - the runmask must match a cluster or it fails
- Scheduling - Algorithms
  1. FIFO
  2. Round Robin
  3. Sporadic
  4. High Priority ISTs
