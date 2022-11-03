infile=open('version.s','r')
current=int(infile.readline().split()[2])
new=current+1
infile.close()
outfile=open('version.s','w')
outfile.write('.equiv VERSION,    %d\n' % new)
outfile.close()
