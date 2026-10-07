"""Structural-image evidence provider for Photo Survey World.

This module deliberately does not solve SurveyWorld geometry.  It extracts a
small set of long straight-image segment statistics as derived evidence.  The
ooRexx side remains responsible for survey semantics and Maths remains the
numerical authority for reconstruction.
"""

import math
import cv2


class PhotoWorldStructureProvider:
    def __init__(self, provider_name="OpenCV LSD structure", version="0.1", min_length="120"):
        self.provider_name = provider_name
        self.version = version
        self.min_length = float(min_length)
        self.calls = 0

    def providerversion(self):
        return self.version

    def callcount(self):
        return self.calls

    @staticmethod
    def _orientation(angle_degrees):
        angle = angle_degrees % 180.0
        if 75.0 <= angle <= 105.0:
            return "V"
        if angle <= 15.0 or angle >= 165.0:
            return "H"
        return "D"

    def analyze(self, source_ref):
        self.calls += 1
        image = cv2.imread(source_ref, cv2.IMREAD_GRAYSCALE)
        if image is None:
            raise ValueError(f"cannot read image: {source_ref}")
        detector = cv2.createLineSegmentDetector(cv2.LSD_REFINE_STD)
        detected = detector.detect(image)[0]
        counts = {"V": 0, "H": 0, "D": 0}
        longest = {"V": 0.0, "H": 0.0, "D": 0.0}
        accepted = 0
        if detected is not None:
            for item in detected[:, 0, :]:
                x1, y1, x2, y2 = (float(v) for v in item)
                length = math.hypot(x2 - x1, y2 - y1)
                if length < self.min_length:
                    continue
                angle = math.degrees(math.atan2(y2 - y1, x2 - x1))
                family = self._orientation(angle)
                counts[family] += 1
                accepted += 1
                if length > longest[family]:
                    longest[family] = length
        height, width = image.shape[:2]
        return (
            f"STRUCTURE:v1:{width}x{height}:segments={accepted}:"
            f"V={counts['V']}:H={counts['H']}:D={counts['D']}:"
            f"LV={longest['V']:.3f}:LH={longest['H']:.3f}:LD={longest['D']:.3f}"
        )
