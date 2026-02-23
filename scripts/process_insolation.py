"""
Model exported as python.
Name : calculate-insolation
Group : 
With QGIS : 34407
"""

from typing import Any, Optional

from qgis.core import QgsProcessing
from qgis.core import QgsProcessingAlgorithm
from qgis.core import QgsProcessingContext
from qgis.core import QgsProcessingFeedback, QgsProcessingMultiStepFeedback
from qgis.core import QgsProcessingParameterRasterLayer
from qgis.core import QgsProcessingParameterFile
from qgis.core import QgsProcessingParameterFolderDestination
from qgis.core import QgsProcessingParameterRasterDestination
from qgis import processing


class Calculateinsolation(QgsProcessingAlgorithm):

    def initAlgorithm(self, config: Optional[dict[str, Any]] = None):
        self.addParameter(QgsProcessingParameterRasterLayer('building__ground_dsm', 'Building & Ground DSM', defaultValue=None))
        self.addParameter(QgsProcessingParameterRasterLayer('vegetation_dsm', 'Vegetation DSM', defaultValue=None))
        # This should be converted to a pre-UMEP file down the line, we just need the requirements for such a file type...
        self.addParameter(QgsProcessingParameterFile('meteorological_data_umeped', 'Meteorological Data (UMEPed)', behavior=QgsProcessingParameterFile.File, fileFilter='Text Files (*.txt)', defaultValue=None))
        self.addParameter(QgsProcessingParameterFolderDestination('Outputdir', 'output-dir', createByDefault=True, defaultValue=None))
        self.addParameter(QgsProcessingParameterRasterDestination('Rooftopirradiance', 'rooftop-irradiance', optional=True, createByDefault=False, defaultValue=None))

    def processAlgorithm(self, parameters: dict[str, Any], context: QgsProcessingContext, model_feedback: QgsProcessingFeedback) -> dict[str, Any]:
        # Use a multi-step feedback, so that individual child algorithm progress reports are adjusted for the
        # overall progress through the model
        feedback = QgsProcessingMultiStepFeedback(2, model_feedback)
        results = {}
        outputs = {}

        # Urban Geometry: Wall Height and Aspect
        # We don't really care about the walls for our analysis (?), but it's still required.
        alg_params = {
            'INPUT': parameters['building__ground_dsm'],
            'INPUT_LIMIT': 3,
            'OUTPUT_ASPECT': QgsProcessing.TEMPORARY_OUTPUT,
            'OUTPUT_HEIGHT': QgsProcessing.TEMPORARY_OUTPUT
        }
        outputs['UrbanGeometryWallHeightAndAspect'] = processing.run('umep:Urban Geometry: Wall Height and Aspect', alg_params, context=context, feedback=feedback, is_child_algorithm=True)

        feedback.setCurrentStep(1)
        if feedback.isCanceled():
            return {}

        # Solar Radiation: Solar Energy of Builing Envelopes (SEBE)
        alg_params = {
            'ALBEDO': 0.15,
            'INPUTMET': parameters['meteorological_data_umeped'],
            'INPUT_ASPECT': outputs['UrbanGeometryWallHeightAndAspect']['OUTPUT_ASPECT'],
            'INPUT_CDSM': parameters['vegetation_dsm'],
            'INPUT_DSM': parameters['building__ground_dsm'],
            'INPUT_HEIGHT': outputs['UrbanGeometryWallHeightAndAspect']['OUTPUT_HEIGHT'],
            'INPUT_TDSM': None,
            'INPUT_THEIGHT': 25,
            'ONLYGLOBAL': False,
            'SAVESKYIRR': False,
            'TRANS_VEG': 3,
            'UTC': 5,  # UTC-08:00
            'IRR_FILE': QgsProcessing.TEMPORARY_OUTPUT,
            'OUTPUT_DIR': parameters['Outputdir'],
            'OUTPUT_ROOF': parameters['Rooftopirradiance']
        }
        outputs['SolarRadiationSolarEnergyOfBuilingEnvelopesSebe'] = processing.run('umep:Solar Radiation: Solar Energy of Builing Envelopes (SEBE)', alg_params, context=context, feedback=feedback, is_child_algorithm=True)
        results['Outputdir'] = outputs['SolarRadiationSolarEnergyOfBuilingEnvelopesSebe']['OUTPUT_DIR']
        results['Rooftopirradiance'] = outputs['SolarRadiationSolarEnergyOfBuilingEnvelopesSebe']['OUTPUT_ROOF']
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
