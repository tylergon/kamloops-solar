"""
Model exported as python.
Name : calculate-insolation
Group : 
With QGIS : 40002
"""

from typing import Any, Optional

from qgis.core import QgsProcessing
from qgis.core import QgsProcessingAlgorithm
from qgis.core import QgsProcessingContext
from qgis.core import QgsProcessingFeedback, QgsProcessingMultiStepFeedback
from qgis.core import QgsProcessingParameterRasterLayer
from qgis.core import QgsProcessingParameterFile
from qgis import processing


class Calculateinsolation(QgsProcessingAlgorithm):

    def initAlgorithm(self, config: Optional[dict[str, Any]] = None):
        self.addParameter(QgsProcessingParameterRasterLayer('building__ground_dsm', 'Building & Ground DSM', defaultValue=None))
        # This should be converted to a pre-UMEP file down the line, we just need the requirements for such a file type...
        self.addParameter(QgsProcessingParameterFile('meteorological_data_umeped', 'Meteorological Data (UMEPed)', behavior=QgsProcessingParameterFile.File, fileFilter='Text Files (*.txt)', defaultValue=None))
        self.addParameter(QgsProcessingParameterRasterLayer('vegetation_dsm', 'Vegetation DSM', defaultValue=None))

    def processAlgorithm(self, parameters: dict[str, Any], context: QgsProcessingContext, model_feedback: QgsProcessingFeedback) -> dict[str, Any]:
        # Use a multi-step feedback, so that individual child algorithm progress reports are adjusted for the
        # overall progress through the model
        feedback = QgsProcessingMultiStepFeedback(0, model_feedback)
        results = {}
        outputs = {}

        return results

    def name(self) -> str:
        return 'calculate-insolation'

    def displayName(self) -> str:
        return 'calculate-insolation'

    def group(self) -> str:
        return ''

    def groupId(self) -> str:
        return ''

    def createInstance(self):
        return self.__class__()
