/*Quick prototype to ensure I understand how
 * kqueue works when tracking children*/

/*Takeaway:
 * 1. It is safe to set the trac event in the parent and ignore the race
 *    condition of child exit.  It appears the child exit event will still
 *    be generated even if the child exits before the event is created.  I
 *    imagine this is because a child hasn't been reaped yet.
 *
 * 2. Any grandchild process that has exited before the child event was added
 *    in the top level process, will produce events. IOW, the kernel does not
 *    maintain a history of old processes and backfill the events (obviously).
 *
 * 3. Exit status is returned in data.
 *
 * 4. The flags field of the event have ONESHOT, CLEAR and EOF bits set.
 *
 * 5. User data is maintained across new processes.
 *
 * Event: pid=899,filter=fffb,flags=30,fflags=4,data=898,userdata=898
 * Event: pid=89a,filter=fffb,flags=8030,fflags=4,data=899,userdata=898
 * Event: pid=89a,filter=fffb,flags=8030,fflags=80000000,data=700,userdata=898
 * Event: pid=898,filter=fffb,flags=8030,fflags=80000000,data=700,userdata=898
 * Event: pid=899,filter=fffb,flags=8030,fflags=80000000,data=700,userdata=898
 */

#include <array>
#include <string>
#include <iostream>
#include <sys/event.h>
#include <stdlib.h>
#include <unistd.h>

namespace
{
    void fork_child(bool second_fork)
    {
        pid_t pid = fork();
        switch(pid)
        {
        case -1:
            perror("fork_child");
            break;
        case 0:
            if(second_fork)
            {
                sleep(1);
                fork_child(false);
            }
            break;
        default:
            /*parent*/
            sleep(2);
            break;
        }

        exit(7);
    }

    void parent_main(int kq_fd, int child_pid)
    {
        std::cerr << "main child pid: " << child_pid << std::endl;
        while(true)
        {
            std::array<struct kevent, 16> events;
            int num_events = kevent(kq_fd, nullptr, 0, events.data(), events.size(), nullptr);

            std::cerr << std::hex;
            for(int i = 0; i < num_events; ++i)
            {
                std::cerr << "Event: pid=" << events[i].ident << ",filter=" << events[i].filter
                          << ",flags=" << events[i].flags << ",fflags="<< std::hex << events[i].fflags
                          << ",data=" << events[i].data << ",userdata=" << *(pid_t*)events[i].udata << std::endl;
            }
        }
    }
}

int main(int argc, char** argv)
{
    int kq_fd = kqueue();
    if(kq_fd == -1)
    {
        perror("kqueue");
        exit(1);
    }

    struct kevent ev;

    pid_t pid = fork();
    int num_events = 0;
    switch(pid)
    {
    case 0:
        /*child*/
        break;
    default:

        EV_SET(&ev, pid, EVFILT_PROC, EV_ADD, NOTE_EXIT|NOTE_TRACK, 0, &pid);
        num_events = kevent(kq_fd, &ev, 1, nullptr, 0, nullptr);
        if(num_events == -1)
        {
            perror("kevent add");
            exit(1);
        }
        parent_main(kq_fd, pid);
        break;
    case -1:

        break;
    }

    /*child*/

    for(int i = 0; i < 2; ++i)
    {
        fork_child(true);
        sleep(2);
    }

    return 0;
}
