/* Optional Job-to-Node Allocator integration. */
::class HFSpaceAllocatorAdapter public
::method toJobNodeRequirement
  use arg requirement
  abilities=.array~of("HUGGINGFACE_SPACE_EXECUTION")
  tags=.array~of("HUGGINGFACE","HF_SPACE")
  if requirement~accelerator="GPU" then do
    abilities~append("GPU")
    if requirement~tier="ZEROGPU_LARGE" then tags~append("HF_ZEROGPU_LARGE")
    else tags~append("HF_ZEROGPU_XLARGE")
  end
  else tags~append("CPU_ONLY_OK")
  return .JobNodeRequirement~new(.nil,.nil,.nil,.nil,abilities,.array~of("PYTHON"),tags,"",0,0,0,0,0,0,0,.nil,"")
::requires "JobNodeAllocator.cls"
::requires "HuggingFaceSpaceJob.cls"
