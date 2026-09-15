installed=.CryptoForeignRuntimeInstaller~install
key='000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f';nonce='000000000000004a00000000';data=copies('rocket-skates-'||'00ff'x,256)
loops=100
call time 'R';do i=1 to loops;x=.ChaCha20~crypt(data,key,nonce);end;say 'ChaCha20 ~4KiB|'format(time('E')*1000/loops,,3)'|ms avg'
installed['target']~close
::requires 'CryptoForeignRuntimeProvider.cls'
