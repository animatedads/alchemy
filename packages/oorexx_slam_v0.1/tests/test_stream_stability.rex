numeric digits 16
f=.HarbourStreamStability~new
checks=0
call ok f~imagePoint(138,0)[1]=0,'left band maps to raster 0'
call ok f~imagePoint(1398,709)[1]=320,'active width mapping'
call ok f~imagePoint(768,354)[1]=160,'centre coordinate'
call ok f~imagePoint(768,354)[2]=90,'centre y coordinate'
call ok f~anchors(1)~items=3,'western stream anchors'
call ok f~anchors(2)~items=4,'northern stream anchors'
call ok f~anchors(3)~items=4,'cafe stream anchors'
/* Synthetic known displacement on 40x30 grayscale frames. */
w=40;h=30
raw='';frame1='';frame2=''
do y=0 to h-1
  do x=0 to w-1
    z=((x*x*3+y*y*7+x*y*11)//173)+40
    frame1=frame1||d2c(z)
    px=x-2;py=y+1
    z=0
    if px>=0 & px<w & py>=0 & py<h then z=((px*px*3+py*py*7+px*py*11)//173)+40
    frame2=frame2||d2c(z)
  end
end
raw=frame1||frame2
fit=f~fitPatch(raw,w,h,2,20,15,3,4)
call ok fit['DX']=2,'synthetic x+2 displacement recovered'
call ok fit['DY']=-1,'synthetic y-1 displacement recovered'
call ok fit['MAD']=0,'synthetic patch matches exactly'
call ok fit['STATUS']='MEASURED_UNQUALIFIED_CAMERA_SITE','native patch comparison success'
flat=copies(d2c(90),w*h*2)
fit=f~fitPatch(flat,w,h,2,20,15,3,4)
call ok fit['STATUS']='REJECTED_LOW_TEXTURE','featureless patch rejected'
call ok f~patchError(raw,w,h,2,0,0,0,0)<0,'edge patch rejected'
call ok f~admission(.array~of(.array~of(1,'A',2,0,0,0,'MEASURED_UNQUALIFIED_CAMERA_SITE')))= 'FRAME_STABILITY_UNDERSAMPLED','short track not admitted'
a=.array~of(.array~of(1,'A',2,0,0,0,'MEASURED_UNQUALIFIED_CAMERA_SITE'),.array~of(1,'A',3,0,0,0,'MEASURED_UNQUALIFIED_CAMERA_SITE'),.array~of(1,'A',4,0,0,0,'MEASURED_UNQUALIFIED_CAMERA_SITE'))
call ok f~admission(a)='FRAME_STABLE_POSE_UNQUALIFIED','stable image does not qualify geographic pose'
a~append(.array~of(1,'B',2,0,0,99,'REJECTED_PATCH_CHANGED'))
call ok f~admission(a)='FRAME_STABILITY_INCOMPLETE','failed patch rejects stability'
say 'POWER SLAM STREAM STABILITY: ' checks '/' checks 'PASS'
exit 0
ok: procedure expose checks
 use arg condition,label
 if \condition then do
   say 'FAIL' label
   exit 1
 end
 checks+=1
 return
::requires 'SlamHarbourStreamStability.cls'