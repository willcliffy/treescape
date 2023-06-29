import pandas as pd
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import json

# Load your JSON data
with open('output.json') as f:
    data = json.load(f)

# Flatten JSON object into a dataframe
vertices = []
for k, v in data.items():
    for vertex in v['vertices']:
        vertices.append(vertex)

df = pd.DataFrame(vertices)

# Convert string data to float
df[['x', 'y', 'z']] = df[['x', 'y', 'z']].astype(float)

# 3D Plot
fig = plt.figure(figsize=(8, 6))
ax = fig.add_subplot(111, projection='3d')
ax.set_box_aspect([1, 1, 1])

ax.scatter(df['x'], df['y'], df['z'])

ax.set_xlabel('X')
ax.set_ylabel('Y')
ax.set_zlabel('Z')


plt.show()
