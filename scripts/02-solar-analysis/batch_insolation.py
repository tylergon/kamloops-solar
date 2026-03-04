import sys
import os


from qgis.core import QgsApplication, QgsProcessingFeedback
from qgis.analysis import QgsNativeAlgorithms

# 1. Initialize QGIS
QgsApplication.setPrefixPath(r'C:\OSGeo4W\apps\qgis', True)
qgs = QgsApplication([], False)
qgs.initQgis()

# 2. Setup Plugin Paths (Crucial for external plugins)
# Replace with your actual profile plugin path
plugin_path = r'C:\Users\Name\AppData\Roaming\QGIS\QGIS3\profiles\default\python\plugins'
sys.path.append(plugin_path)

# 3. Initialize Processing
import processing
from processing.core.Processing import Processing
Processing.initialize()
QgsApplication.processingRegistry().addProvider(QgsNativeAlgorithms())

# 4. Import your exported model class
# Assuming your exported script is named 'my_model_script.py' 
# and the class is 'MyModelAlgorithm'
from my_model_script import MyModelAlgorithm
alg = MyModelAlgorithm()
alg.initAlgorithm()

# 5. Batch Loop
input_folder = r'C:\data\inputs'
for file in os.listdir(input_folder):
    if file.endswith('.shp'):
        in_path = os.path.join(input_folder, file)
        out_path = os.path.join(r'C:\data\outputs', f"out_{file}")
        
        params = {'INPUT': in_path, 'OUTPUT': out_path}
        processing.run(alg, params, feedback=QgsProcessingFeedback())

qgs.exitQgis()