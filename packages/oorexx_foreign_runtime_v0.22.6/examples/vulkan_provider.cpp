#include <cstdint>
#include <cstddef>
#include <cstdlib>
#include <cstring>
#include <string>
#include <mutex>
#include <dlfcn.h>

using VkFlags=uint32_t; using VkBool32=uint32_t; using VkDeviceSize=uint64_t; using VkResult=int32_t;
using VkInstance=void*; using VkPhysicalDevice=void*; using VkDevice=void*; using VkQueue=void*; using VkCommandBuffer=void*;
using VkBuffer=void*; using VkDeviceMemory=void*; using VkCommandPool=void*; using VkFence=void*;
static constexpr VkResult VK_SUCCESS=0;
static constexpr uint64_t VK_WHOLE_SIZE=~uint64_t(0);
static constexpr uint32_t VK_STRUCTURE_TYPE_APPLICATION_INFO=0;
static constexpr uint32_t VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO=1;
static constexpr uint32_t VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO=2;
static constexpr uint32_t VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO=3;
static constexpr uint32_t VK_STRUCTURE_TYPE_SUBMIT_INFO=4;
static constexpr uint32_t VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO=5;
static constexpr uint32_t VK_STRUCTURE_TYPE_FENCE_CREATE_INFO=8;
static constexpr uint32_t VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO=12;
static constexpr uint32_t VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO=39;
static constexpr uint32_t VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO=40;
static constexpr uint32_t VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO=42;
static constexpr uint32_t VK_API_VERSION_1_0=(1u<<22);
static constexpr VkFlags VK_QUEUE_GRAPHICS_BIT=0x1, VK_QUEUE_COMPUTE_BIT=0x2, VK_QUEUE_TRANSFER_BIT=0x4;
static constexpr VkFlags VK_BUFFER_USAGE_TRANSFER_DST_BIT=0x2, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT=0x20;
static constexpr VkFlags VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT=0x1, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT=0x2, VK_MEMORY_PROPERTY_HOST_COHERENT_BIT=0x4;
static constexpr uint32_t VK_SHARING_MODE_EXCLUSIVE=0, VK_COMMAND_BUFFER_LEVEL_PRIMARY=0;
static constexpr VkFlags VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT=0x1;
static constexpr uint32_t VK_PHYSICAL_DEVICE_TYPE_CPU=4;

struct VkExtent3D { uint32_t width,height,depth; };
struct VkApplicationInfo { uint32_t sType; const void* pNext; const char* pApplicationName; uint32_t applicationVersion; const char* pEngineName; uint32_t engineVersion; uint32_t apiVersion; };
struct VkInstanceCreateInfo { uint32_t sType; const void* pNext; VkFlags flags; const VkApplicationInfo* pApplicationInfo; uint32_t enabledLayerCount; const char* const* ppEnabledLayerNames; uint32_t enabledExtensionCount; const char* const* ppEnabledExtensionNames; };
struct VkDeviceQueueCreateInfo { uint32_t sType; const void* pNext; VkFlags flags; uint32_t queueFamilyIndex; uint32_t queueCount; const float* pQueuePriorities; };
struct VkDeviceCreateInfo { uint32_t sType; const void* pNext; VkFlags flags; uint32_t queueCreateInfoCount; const VkDeviceQueueCreateInfo* pQueueCreateInfos; uint32_t enabledLayerCount; const char* const* ppEnabledLayerNames; uint32_t enabledExtensionCount; const char* const* ppEnabledExtensionNames; const void* pEnabledFeatures; };
struct VkQueueFamilyProperties { VkFlags queueFlags; uint32_t queueCount; uint32_t timestampValidBits; VkExtent3D minImageTransferGranularity; };
struct VkMemoryType { VkFlags propertyFlags; uint32_t heapIndex; };
struct VkMemoryHeap { VkDeviceSize size; VkFlags flags; };
struct VkPhysicalDeviceMemoryProperties { uint32_t memoryTypeCount; VkMemoryType memoryTypes[32]; uint32_t memoryHeapCount; VkMemoryHeap memoryHeaps[16]; };
struct VkBufferCreateInfo { uint32_t sType; const void* pNext; VkFlags flags; VkDeviceSize size; VkFlags usage; uint32_t sharingMode; uint32_t queueFamilyIndexCount; const uint32_t* pQueueFamilyIndices; };
struct VkMemoryRequirements { VkDeviceSize size; VkDeviceSize alignment; uint32_t memoryTypeBits; };
struct VkMemoryAllocateInfo { uint32_t sType; const void* pNext; VkDeviceSize allocationSize; uint32_t memoryTypeIndex; };
struct VkCommandPoolCreateInfo { uint32_t sType; const void* pNext; VkFlags flags; uint32_t queueFamilyIndex; };
struct VkCommandBufferAllocateInfo { uint32_t sType; const void* pNext; VkCommandPool commandPool; uint32_t level; uint32_t commandBufferCount; };
struct VkCommandBufferBeginInfo { uint32_t sType; const void* pNext; VkFlags flags; const void* pInheritanceInfo; };
struct VkFenceCreateInfo { uint32_t sType; const void* pNext; VkFlags flags; };
struct VkSubmitInfo { uint32_t sType; const void* pNext; uint32_t waitSemaphoreCount; const void* pWaitSemaphores; const void* pWaitDstStageMask; uint32_t commandBufferCount; const VkCommandBuffer* pCommandBuffers; uint32_t signalSemaphoreCount; const void* pSignalSemaphores; };
struct PhysicalPropsFront { uint32_t apiVersion,driverVersion,vendorID,deviceID,deviceType; char deviceName[256]; uint8_t pipelineCacheUUID[16]; };

struct TensorImportV2 {
  void *data; size_t byte_size; int readonly; int device_type; int device_id;
  int dtype_code; int dtype_bits; int dtype_lanes; size_t ndim;
  const int64_t *shape; const int64_t *strides_bytes;
  void *token; void (*release)(void*);
  const char *execution_provider; uint64_t stream_handle; uint64_t fence_handle;
  int sync_policy; int affinity_kind;
};
struct TensorExportV2 {
  void *data; size_t byte_size; int readonly; int device_type; int device_id;
  int dtype_code; int dtype_bits; int dtype_lanes; size_t ndim;
  const int64_t *shape; const int64_t *strides_bytes; void *token;
  const char *execution_provider; uint64_t stream_handle; uint64_t fence_handle;
  int sync_policy; int affinity_kind;
};
using TensorImportFn=uint64_t(*)(const TensorImportV2*); using TensorAcquireFn=int(*)(uint64_t,TensorExportV2*); using TensorReleaseFn=void(*)(void*); using TensorCloseFn=int(*)(uint64_t);

struct VulkanFns {
  void* so=nullptr;
  VkResult(*CreateInstance)(const VkInstanceCreateInfo*,const void*,VkInstance*)=nullptr;
  void(*DestroyInstance)(VkInstance,const void*)=nullptr;
  VkResult(*EnumeratePhysicalDevices)(VkInstance,uint32_t*,VkPhysicalDevice*)=nullptr;
  void(*GetPhysicalDeviceProperties)(VkPhysicalDevice,void*)=nullptr;
  void(*GetPhysicalDeviceQueueFamilyProperties)(VkPhysicalDevice,uint32_t*,VkQueueFamilyProperties*)=nullptr;
  void(*GetPhysicalDeviceMemoryProperties)(VkPhysicalDevice,VkPhysicalDeviceMemoryProperties*)=nullptr;
  VkResult(*CreateDevice)(VkPhysicalDevice,const VkDeviceCreateInfo*,const void*,VkDevice*)=nullptr;
  void(*DestroyDevice)(VkDevice,const void*)=nullptr;
  void(*GetDeviceQueue)(VkDevice,uint32_t,uint32_t,VkQueue*)=nullptr;
  VkResult(*CreateBuffer)(VkDevice,const VkBufferCreateInfo*,const void*,VkBuffer*)=nullptr;
  void(*DestroyBuffer)(VkDevice,VkBuffer,const void*)=nullptr;
  void(*GetBufferMemoryRequirements)(VkDevice,VkBuffer,VkMemoryRequirements*)=nullptr;
  VkResult(*AllocateMemory)(VkDevice,const VkMemoryAllocateInfo*,const void*,VkDeviceMemory*)=nullptr;
  void(*FreeMemory)(VkDevice,VkDeviceMemory,const void*)=nullptr;
  VkResult(*BindBufferMemory)(VkDevice,VkBuffer,VkDeviceMemory,VkDeviceSize)=nullptr;
  VkResult(*MapMemory)(VkDevice,VkDeviceMemory,VkDeviceSize,VkDeviceSize,VkFlags,void**)=nullptr;
  void(*UnmapMemory)(VkDevice,VkDeviceMemory)=nullptr;
  VkResult(*CreateCommandPool)(VkDevice,const VkCommandPoolCreateInfo*,const void*,VkCommandPool*)=nullptr;
  void(*DestroyCommandPool)(VkDevice,VkCommandPool,const void*)=nullptr;
  VkResult(*AllocateCommandBuffers)(VkDevice,const VkCommandBufferAllocateInfo*,VkCommandBuffer*)=nullptr;
  VkResult(*BeginCommandBuffer)(VkCommandBuffer,const VkCommandBufferBeginInfo*)=nullptr;
  void(*CmdFillBuffer)(VkCommandBuffer,VkBuffer,VkDeviceSize,VkDeviceSize,uint32_t)=nullptr;
  VkResult(*EndCommandBuffer)(VkCommandBuffer)=nullptr;
  VkResult(*CreateFence)(VkDevice,const VkFenceCreateInfo*,const void*,VkFence*)=nullptr;
  void(*DestroyFence)(VkDevice,VkFence,const void*)=nullptr;
  VkResult(*QueueSubmit)(VkQueue,uint32_t,const VkSubmitInfo*,VkFence)=nullptr;
  VkResult(*WaitForFences)(VkDevice,uint32_t,const VkFence*,VkBool32,uint64_t)=nullptr;
  VkResult(*DeviceWaitIdle)(VkDevice)=nullptr;
};

static std::mutex gmu; static VulkanFns vf; static std::string lastName; static uint32_t lastVendor=0,lastDevice=0,lastType=0; static void* selfPin=nullptr;
static void promote_runtime(){void*h=dlopen("libforeign_runtime.so",RTLD_NOW|RTLD_NOLOAD|RTLD_GLOBAL);if(h)dlclose(h);}
static void pin_self(){if(selfPin)return;Dl_info di{};if(dladdr((void*)&pin_self,&di)&&di.dli_fname)selfPin=dlopen(di.dli_fname,RTLD_NOW|RTLD_LOCAL);}
static bool load_vulkan(){
  std::lock_guard<std::mutex>g(gmu); if(vf.so)return true; vf.so=dlopen("libvulkan.so.1",RTLD_NOW|RTLD_LOCAL); if(!vf.so)return false;
#define L(name) vf.name=(decltype(vf.name))dlsym(vf.so,"vk" #name); if(!vf.name)return false
  L(CreateInstance);L(DestroyInstance);L(EnumeratePhysicalDevices);L(GetPhysicalDeviceProperties);L(GetPhysicalDeviceQueueFamilyProperties);L(GetPhysicalDeviceMemoryProperties);L(CreateDevice);L(DestroyDevice);L(GetDeviceQueue);L(CreateBuffer);L(DestroyBuffer);L(GetBufferMemoryRequirements);L(AllocateMemory);L(FreeMemory);L(BindBufferMemory);L(MapMemory);L(UnmapMemory);L(CreateCommandPool);L(DestroyCommandPool);L(AllocateCommandBuffers);L(BeginCommandBuffer);L(CmdFillBuffer);L(EndCommandBuffer);L(CreateFence);L(DestroyFence);L(QueueSubmit);L(WaitForFences);L(DeviceWaitIdle);
#undef L
  return true;
}
struct VulkanTensor {
  VkInstance instance=nullptr; VkDevice device=nullptr; VkQueue queue=nullptr; VkBuffer buffer=nullptr; VkDeviceMemory memory=nullptr; VkCommandPool pool=nullptr; VkFence fence=nullptr; void* mapped=nullptr;
  uint32_t vendor=0,deviceId=0,deviceType=0; std::string name; int64_t shape[1]{0}; int64_t stride[1]{4};
};
static void release_vulkan_tensor(void*vp){
  auto*t=static_cast<VulkanTensor*>(vp); if(!t)return;
  if(t->device&&vf.DeviceWaitIdle)vf.DeviceWaitIdle(t->device);
  if(t->device&&t->fence)vf.DestroyFence(t->device,t->fence,nullptr);
  if(t->device&&t->pool)vf.DestroyCommandPool(t->device,t->pool,nullptr);
  if(t->device&&t->mapped)vf.UnmapMemory(t->device,t->memory);
  if(t->device&&t->buffer)vf.DestroyBuffer(t->device,t->buffer,nullptr);
  if(t->device&&t->memory)vf.FreeMemory(t->device,t->memory,nullptr);
  if(t->device)vf.DestroyDevice(t->device,nullptr);
  if(t->instance)vf.DestroyInstance(t->instance,nullptr);
  delete t;
}
static bool select_device(VkInstance inst,uint32_t requiredVendor,VkPhysicalDevice*chosen,PhysicalPropsFront*front,uint32_t*qfam){
  uint32_t n=0;if(vf.EnumeratePhysicalDevices(inst,&n,nullptr)!=VK_SUCCESS||!n)return false; auto*devs=new VkPhysicalDevice[n]; bool ok=false;
  if(vf.EnumeratePhysicalDevices(inst,&n,devs)==VK_SUCCESS){for(uint32_t i=0;i<n&&!ok;i++){
    alignas(16) unsigned char raw[4096]{};vf.GetPhysicalDeviceProperties(devs[i],raw);auto*p=(PhysicalPropsFront*)raw;
    if(p->deviceType==VK_PHYSICAL_DEVICE_TYPE_CPU) continue;
    if(requiredVendor && p->vendorID!=requiredVendor) continue;
    uint32_t qn=0;vf.GetPhysicalDeviceQueueFamilyProperties(devs[i],&qn,nullptr); if(!qn)continue; auto*q=new VkQueueFamilyProperties[qn];vf.GetPhysicalDeviceQueueFamilyProperties(devs[i],&qn,q);
    for(uint32_t j=0;j<qn;j++){
      if(q[j].queueCount && (q[j].queueFlags&(VK_QUEUE_COMPUTE_BIT|VK_QUEUE_GRAPHICS_BIT|VK_QUEUE_TRANSFER_BIT))){*chosen=devs[i];*front=*p;*qfam=j;ok=true;break;}
    }
    delete[] q;
  }} delete[]devs; return ok;
}
static int choose_memory(VkPhysicalDevice pd,uint32_t bits){VkPhysicalDeviceMemoryProperties mp{};vf.GetPhysicalDeviceMemoryProperties(pd,&mp);for(uint32_t pass=0;pass<2;pass++)for(uint32_t i=0;i<mp.memoryTypeCount;i++){if(!(bits&(1u<<i)))continue;VkFlags f=mp.memoryTypes[i].propertyFlags;VkFlags need=VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT|VK_MEMORY_PROPERTY_HOST_COHERENT_BIT|(pass==0?VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT:0);if((f&need)==need)return (int)i;}return -1;}

extern "C" int foreign_vulkan_available(uint32_t requiredVendor){
  if(!load_vulkan()) return 0;
  VkApplicationInfo ai{VK_STRUCTURE_TYPE_APPLICATION_INFO,nullptr,"ooRexx Foreign Runtime",1,"foreign.vulkan",1,VK_API_VERSION_1_0};VkInstanceCreateInfo ci{VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,nullptr,0,&ai,0,nullptr,0,nullptr};VkInstance inst=nullptr;if(vf.CreateInstance(&ci,nullptr,&inst)!=VK_SUCCESS)return 0;VkPhysicalDevice pd=nullptr;PhysicalPropsFront p{};uint32_t q=0;bool ok=select_device(inst,requiredVendor,&pd,&p,&q);if(ok){lastName=p.deviceName;lastVendor=p.vendorID;lastDevice=p.deviceID;lastType=p.deviceType;}vf.DestroyInstance(inst,nullptr);return ok?1:0;
}
extern "C" const char* foreign_vulkan_last_device_name(){return lastName.c_str();}
extern "C" uint32_t foreign_vulkan_last_vendor_id(){return lastVendor;}
extern "C" uint32_t foreign_vulkan_last_device_id(){return lastDevice;}
extern "C" uint32_t foreign_vulkan_last_device_type(){return lastType;}

extern "C" uint64_t foreign_vulkan_fill_tensor(uint32_t count,uint32_t pattern,uint32_t requiredVendor){
  if(!count||!load_vulkan()) return 0;
  promote_runtime(); pin_self();
  auto imp=(TensorImportFn)dlsym(RTLD_DEFAULT,"rexx_foreign_tensor_import_v2");if(!imp)return 0;
  auto*t=new VulkanTensor();VkApplicationInfo ai{VK_STRUCTURE_TYPE_APPLICATION_INFO,nullptr,"ooRexx Foreign Runtime",1,"foreign.vulkan",1,VK_API_VERSION_1_0};VkInstanceCreateInfo ici{VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,nullptr,0,&ai,0,nullptr,0,nullptr};
  if(vf.CreateInstance(&ici,nullptr,&t->instance)!=VK_SUCCESS){release_vulkan_tensor(t);return 0;}VkPhysicalDevice pd=nullptr;PhysicalPropsFront p{};uint32_t qfam=0;if(!select_device(t->instance,requiredVendor,&pd,&p,&qfam)){release_vulkan_tensor(t);return 0;}
  t->vendor=p.vendorID;t->deviceId=p.deviceID;t->deviceType=p.deviceType;t->name=p.deviceName;lastName=t->name;lastVendor=t->vendor;lastDevice=t->deviceId;lastType=t->deviceType;
  float prio=1.0f;VkDeviceQueueCreateInfo qci{VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,nullptr,0,qfam,1,&prio};VkDeviceCreateInfo dci{VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,nullptr,0,1,&qci,0,nullptr,0,nullptr,nullptr};if(vf.CreateDevice(pd,&dci,nullptr,&t->device)!=VK_SUCCESS){release_vulkan_tensor(t);return 0;}vf.GetDeviceQueue(t->device,qfam,0,&t->queue);
  VkDeviceSize bytes=(VkDeviceSize)count*4;VkBufferCreateInfo bci{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,nullptr,0,bytes,VK_BUFFER_USAGE_TRANSFER_DST_BIT|VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,VK_SHARING_MODE_EXCLUSIVE,0,nullptr};if(vf.CreateBuffer(t->device,&bci,nullptr,&t->buffer)!=VK_SUCCESS){release_vulkan_tensor(t);return 0;}
  VkMemoryRequirements mr{};vf.GetBufferMemoryRequirements(t->device,t->buffer,&mr);int mt=choose_memory(pd,mr.memoryTypeBits);if(mt<0){release_vulkan_tensor(t);return 0;}VkMemoryAllocateInfo mai{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,nullptr,mr.size,(uint32_t)mt};if(vf.AllocateMemory(t->device,&mai,nullptr,&t->memory)!=VK_SUCCESS||vf.BindBufferMemory(t->device,t->buffer,t->memory,0)!=VK_SUCCESS||vf.MapMemory(t->device,t->memory,0,mr.size,0,&t->mapped)!=VK_SUCCESS){release_vulkan_tensor(t);return 0;}
  std::memset(t->mapped,0,(size_t)bytes);VkCommandPoolCreateInfo pci{VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,nullptr,0,qfam};if(vf.CreateCommandPool(t->device,&pci,nullptr,&t->pool)!=VK_SUCCESS){release_vulkan_tensor(t);return 0;}VkCommandBufferAllocateInfo cai{VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,nullptr,t->pool,VK_COMMAND_BUFFER_LEVEL_PRIMARY,1};VkCommandBuffer cb=nullptr;if(vf.AllocateCommandBuffers(t->device,&cai,&cb)!=VK_SUCCESS){release_vulkan_tensor(t);return 0;}VkCommandBufferBeginInfo cbi{VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,nullptr,VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,nullptr};if(vf.BeginCommandBuffer(cb,&cbi)!=VK_SUCCESS){release_vulkan_tensor(t);return 0;}vf.CmdFillBuffer(cb,t->buffer,0,bytes,pattern);if(vf.EndCommandBuffer(cb)!=VK_SUCCESS){release_vulkan_tensor(t);return 0;}VkFenceCreateInfo fci{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,nullptr,0};if(vf.CreateFence(t->device,&fci,nullptr,&t->fence)!=VK_SUCCESS){release_vulkan_tensor(t);return 0;}VkSubmitInfo si{VK_STRUCTURE_TYPE_SUBMIT_INFO,nullptr,0,nullptr,nullptr,1,&cb,0,nullptr};if(vf.QueueSubmit(t->queue,1,&si,t->fence)!=VK_SUCCESS||vf.WaitForFences(t->device,1,&t->fence,1,5000000000ULL)!=VK_SUCCESS){release_vulkan_tensor(t);return 0;}
  t->shape[0]=count;TensorImportV2 in{t->mapped,(size_t)bytes,0,7,(int)t->deviceId,1,32,1,1,t->shape,t->stride,t,release_vulkan_tensor,"vulkan",(uint64_t)(uintptr_t)t->queue,(uint64_t)(uintptr_t)t->fence,2,2};uint64_t id=imp(&in);if(!id)release_vulkan_tensor(t);return id;
}
extern "C" uint32_t foreign_vulkan_tensor_read_u32(uint64_t id,uint32_t index){promote_runtime();auto ac=(TensorAcquireFn)dlsym(RTLD_DEFAULT,"rexx_foreign_tensor_export_acquire_v2");auto rel=(TensorReleaseFn)dlsym(RTLD_DEFAULT,"rexx_foreign_tensor_export_release_v2");if(!ac||!rel)return 0;TensorExportV2 x{};if(ac(id,&x)!=0)return 0;uint32_t v=0;if(x.device_type==7&&x.execution_provider&&std::strcmp(x.execution_provider,"vulkan")==0&&x.dtype_code==1&&x.dtype_bits==32&&index<x.byte_size/4)v=((uint32_t*)x.data)[index];rel(x.token);return v;}
extern "C" int foreign_vulkan_tensor_close(uint64_t id){promote_runtime();auto c=(TensorCloseFn)dlsym(RTLD_DEFAULT,"rexx_foreign_tensor_close_v1");return c?c(id):-90;}
