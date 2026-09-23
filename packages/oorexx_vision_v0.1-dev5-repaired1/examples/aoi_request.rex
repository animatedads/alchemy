/* A high-detail request remains metadata + Storage references. */
sourceRef = "storage:raw/parliament/source"
face = .VisionRegion~new(12, 8, 15, 20, 4, 17)
request = .VisionRegionRequest~new(sourceRef, face, 4, 17)
request~requestedSpatialResolution = "SOURCE"
request~requestedBits = 8
request~requestedValueCount = 256
request~purpose = "FACE_DETAIL"
say request~sourceRef request~startTime request~endTime request~requestedBits request~requestedValueCount
::requires "../src/Vision.cls"
