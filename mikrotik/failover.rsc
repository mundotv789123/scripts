:local lteInterface "lte1"
:local ethInterface "ether1"

:if ( [interface lte find name=$lteInterface] ) do={
  :if ( [ping 8.8.8.8 interface=$ethInterface count=2] = 0 ) do={
    :if ( [interface lte get [find name=$lteInterface] disabled] ) do={
      interface lte enable $lteInterface
      :beep frequency=900 length=0.5
    } else={
      :beep frequency=600 length=0.05
    }
  } else={
    :if ( ![interface lte get [find name=$lteInterface] disabled] ) do={
      interface lte disable $lteInterface
      :beep frequency=1200 length=200ms
      :delay 250ms
      :beep frequency=1200 length=200ms
    }
  }
} else={
  :beep frequency=1200 length=0.1
}