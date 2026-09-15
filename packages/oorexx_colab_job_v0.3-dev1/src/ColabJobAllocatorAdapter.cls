/* Optional Job-to-Node Allocator integration for ooRexx Colab Job v0.2. */
::class ColabAllocatorAdapter public
::method toJobNodeRequirement
  use arg colabRequirement
  abilities=.array~of("COLAB_EXECUTION")
  tags=.array~new; tags~append("COLAB")
  select
    when colabRequirement~accelerator="GPU" then do; abilities~append("GPU"); tags~append("GPU_" || colabRequirement~acceleratorModel); end
    when colabRequirement~accelerator="TPU" then do; abilities~append("TPU"); tags~append("TPU_" || colabRequirement~acceleratorModel); end
    otherwise tags~append("CPU_ONLY_OK")
  end
  if colabRequirement~highMemory then tags~append("HIGH_MEMORY")
  return .JobNodeRequirement~new(.nil,.nil,.nil,.nil,abilities,.array~of("PYTHON"),tags,"",colabRequirement~minimumMemoryMiB,colabRequirement~minimumDiskMiB,0,0,0,0,0,.nil,"")
::requires "JobNodeAllocator.cls"
::requires "ColabJob.cls"
