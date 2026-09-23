function mul(a,b){let o=new Array(16).fill(0);for(let c=0;c<4;c++)for(let r=0;r<4;r++)for(let k=0;k<4;k++)o[c*4+r]+=a[k*4+r]*b[c*4+k];return o}
function persp(f,a,n,z){let t=1/Math.tan(f/2);return[t/a,0,0,0,0,t,0,0,0,0,(z+n)/(n-z),-1,0,0,2*z*n/(n-z),0]}
function model(x,y,z,s=.7){let yaw=.45,pitch=.35,distance=14,cy=Math.cos(yaw),sy=Math.sin(yaw),cp=Math.cos(pitch),sp=Math.sin(pitch);return[cy*s,sy*sp*s,-sy*cp*s,0,0,cp*s,sp*s,0,sy*s,-cy*sp*s,cy*cp*s,0,x,y,z-distance,1]}
for(const [x,z] of [[-3,0],[3,0],[0,-2]]){const m=mul(persp(1.05,360/700,.1,100),model(x,0,z));const nx=m[12]/m[15],ny=m[13]/m[15],nz=m[14]/m[15];if(!Number.isFinite(nx)||Math.abs(nx)>1||Math.abs(ny)>1||nz < -1||nz > 1)throw new Error(`clip regression ${x},${z}: ${nx},${ny},${nz}`)}
console.log('PASS Wire3D column-major clip-space regression');
