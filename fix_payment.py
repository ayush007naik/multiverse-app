content = open('./lib/screen/payment_screen_v2.dart').read()
old = ' total: widget.total,\n ),'
new = ' total: widget.total,\n shopName: widget.shopName,\n ),'
if old in content:
 content = content.replace(old, new,1)
 open('./lib/screen/payment_screen_v2.dart', 'w').write(content)
 print('SUCCESS')
else:
 print('NOT FOUND')
 idx = content.find('total: widget.total')
 if idx >=0:
 print(repr(content[idx-15:idx+35]))
