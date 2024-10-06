:global ltemode
:global iptest "8.8.8.8"
:global routecomment "failover v2"

:if ( [interface lte find name=lte1] ) do={
  :local routedistance [ /ip route get [ /ip route find comment=$routecomment ] distance ]

  :if ( ltemode or [ping $iptest interface=ether1 count=6 interval=150ms] < 3 ) do={
    :if ( $routedistance = 2 ) do={
      /ip route set [ /ip route find comment=$routecomment ] distance=1
      :beep frequency=900 length=0.5
      :log info ("LTE route failover was enabled!")
    } else={
      :beep frequency=600 length=0.05
    }
  } else={
    :if ( $routedistance = 1 ) do={
      /ip route set [ /ip route find comment=$routecomment ] distance=2
      :log info ("LTE route failover was disabled!")
      :beep frequency=1200 length=200ms
      :delay 250ms
      :beep frequency=1200 length=200ms
    }
  }

} else={
  :beep frequency=1200 length=0.1
}