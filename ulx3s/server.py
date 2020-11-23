import socket
import uselect
import sys
import re


addr = socket.getaddrinfo('0.0.0.0', 5500)[0][-1]
poller = uselect.poll()

s = socket.socket()
s.bind(addr)
s.listen(0)
print('listening on', addr)
con = None
print("UP")
poller.register(s,uselect.POLLIN)
poller.register(sys.stdin,uselect.POLLIN)
packet = ""
f=open("gdb.log","w")
f.close()
#f=open("gdb_raw.log","w")
#f.close()
ubuf = bytearray(1)
rbuf = bytearray(2048)
run = True
lpol=uselect.poll()
while run:
    events = poller.poll()
    try:
        for e in events:
            #print(e)
            if e[0]==s:
                # Event on listening socket
                #print(con)
                c2, addr = s.accept()
                #print('client connected from', addr)
                if con==None:
                    con=c2
                    poller.register(con, uselect.POLLIN)
                    con.setblocking(False)
                else: # Already a connection
                    c2.send("Sorry, only one connection allowed\n")
                    c2.close()

            elif e[0]==con:
                # Event on connection
                l=con.readinto(rbuf)
                #print(len)
                if l==0:
                    con.close()
                    con=None
                else:
                    sys.stdout.write(rbuf[0:l])
                # f=open("gdb.log","a")
                # f.write("<<")
                # f.write(rbuf)
                # f.write("\n")
                # f.close()

            elif e[0]==sys.stdin:
                sys.stdin.readinto(ubuf,1)
                if ubuf[0]==4:
                    run=False
                    print("close")
                    break
                if con:
                    con.send(ubuf)
                    # Fast read rest of input
                    lpol.register(sys.stdin,uselect.POLLIN)
                    while lpol.poll(0):
                         sys.stdin.readinto(ubuf,1)
                         con.send(ubuf)
                    lpol.unregister(sys.stdin)

                # if packet=="" and (ubuf[0]==ord("+") or ubuf[0]==ord("-")) and con!=None:
                #     con.send(ubuf)
                # else:
                #     packet+=chr(ubuf[0])

                #     if len(packet)>=3 and re.search("#[0-9a-f][0-9a-f]",packet[-3:]): # full gdb response received
                #         # f=open("gdb.log","a")
                #         # f.write(">>"+packet+"\n")
                #         # f.close()
                #         if not con==None:
                #             con.send(packet)
                #         packet=""
    except OSError:
        #print("OSError")
        con.close()
        poller.unregister(con)
        f=open("gdb.log","a")
        f.write("OSError")
        f.close()
        #print("closed\n")
        con=None


if con:
    con.close()

s.close()

