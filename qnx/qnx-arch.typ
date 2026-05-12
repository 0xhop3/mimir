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
