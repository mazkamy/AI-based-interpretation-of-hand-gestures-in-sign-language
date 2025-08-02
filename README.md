# 🤟 Arabic Sign Language Recognition System

This project presents a complete Arabic Sign Language (ArSL) recognition system with two major components:

1. **A deep learning-based sign recognition model** trained using a novel combination of geometric and CNN-based features.
2. **An educational Flutter mobile app** that allows users to explore, learn, and translate Arabic sign language.

---

## 🧠 Core Contributions

- 📊 A **comparative study** of various architectures (CNN, BiLSTM, Transformer).
- 🧼 Novel **image preprocessing** using:
  - **size functions** (6 measurement functions)
  - **Zernike moments** on size function 2d representation
  - **EfficientNetB0** features on segmmented hand images
- 🔀 A **dual-stream model**:
  - Stream 1: BiLSTM on Zernike-moment-based shape functions.
  - Stream 2: Transformer on EfficientNet features.
  - Fusion via an **attention-based layer** for final prediction.

---

## 📁 Dataset

We used a custom Arabic Sign Language dataset of isolated and continuous sign videos.  
📦 **[Link to Dataset]https://hamzah-luqman.github.io/KArSL**

---

## 🧠 Model Architectures and Comparative Study

This project investigates various deep learning architectures for Arabic Sign Language Recognition. We focus on frame-level feature extraction using shape descriptors (moments and size functions), and explore their integration into sequence models such as CNNs, BiLSTMs, and Transformers.

### 🧪 Models Evaluated

We conducted a comparative study of multiple architectures, each leveraging hand-segmented images and geometric preprocessing:

---

#### 📌 1. CNN + Zernike Moments
- **Input**: Zernike moment features extracted from binary hand images.
- **Model**: Shallow convolutional network with fully connected layers.
- **Strengths**: Fast inference and good performance on static signs.
- **Limitations**: Struggles with temporal dynamics or subtle hand motion.

---

#### 📌 2. BiLSTM on Moment Sequences
- **Input**: Sequences of Zernike or Tchebichef moments extracted per frame.
- **Model**: Bidirectional LSTM to capture temporal dependencies.
- **Strengths**: Better suited for continuous gestures and longer word signs.
- **Limitations**: Lower accuracy when shape features alone are insufficient.

---

#### 📌 3. CNN + Size Function Images
- **Input**: Heatmap-like images generated using geometric size functions (e.g., centroid, axis distance).
- **Model**: CNN classifier trained directly on these diagrams.
- **Strengths**: Captures shape deformations more robustly.
- **Limitations**: Limited temporal modeling.

---

#### 📌 4. BiLSTM on Size Function Descriptors
- **Input**: Feature vectors built from 6 different geometric size functions across hand contours.
- **Model**: BiLSTM sequence model.
- **Strengths**: Strong representation of geometric transformations.
- **Limitations**: Still lacks learned visual features.

---

#### 📌 5. Transformer on EfficientNet Features
- **Input**: Visual embeddings from EfficientNetB0 applied to hand-segmented frames.
- **Model**: Transformer encoder for temporal modeling.
- **Strengths**: Learns high-level spatio-temporal patterns.
- **Limitations**: Requires large dataset for training stability.

---

#### 🏆 6. Dual-Stream Fusion Model (Best Model)
- **Input**:  
  - **Stream 1**: Zernike moments computed on size function diagrams for each hand.  
  - **Stream 2**: EfficientNet features from the raw segmented hand images.
- **Architecture**:  
  - BiLSTM for Stream 1 (shape features)  
  - Transformer for Stream 2 (visual features)  
  - Attention-based fusion of both streams.
- **Strengths**: Combines low-level geometric shape info with high-level CNN features.
- **Result**: **Achieved the highest accuracy** across all tested models.

### 🧾 Summary Table

| Model                          | Input Type                  | Architecture             | 
|--------------------------------|-----------------------------|--------------------------|
| CNN + Zernike Moments          | Shape Moments               | CNN                      |
| BiLSTM + Moment Sequences      | Moment Vectors (per frame)  | BiLSTM                   | 
| CNN + Size Function Diagrams   | Geometric Heatmaps          | CNN                      | 
| BiLSTM + Size Function Features| Size Function Descriptors   | BiLSTM                   | 
| Transformer + EfficientNet     | Visual Embeddings           | Transformer              |
| Dual-Stream (Best)             | Moments + Visual Features   | BiLSTM + Transformer + Attention | 

![Accuracy Comparison Table](images/accuracy_table.png)

---

You can find detailed training curves and model files in the `/models` folder.


## 🏆 Best Performing Model Architecture

Our best-performing model combined geometric descriptors and CNN-based visual features in a dual-stream setup. Each frame was segmented into left/right hands, then processed separately:

- **Zernike Stream**:
  - Input: Zernike moments of size function images.
  - Architecture: BiLSTM.

- **EfficientNet Stream**:
  - Input: RGB segmented hand images.
  - Architecture: Transformer.

- **Fusion**: Attention-based fusion of both streams for robust recognition.

📊 Here's a graph of the architecture:

![Dual Stream Architecture](images/dual_stream_architecture.png)

---
## 📈 Best Model Accuracy Graphs

Below are the training and validation accuracy curves of the best-performing model (Zernike + EfficientNet with attentional fusion):

### 🔹 ACCURACY, F1 SCORE, PRECISION, LOSS over epochs

![metrics Graph](images/model_graphs.png)


---

## 📱 Flutter App (ArSL Learn & Translate)

An educational mobile app built with Flutter to promote Arabic sign language awareness and accessibility.

### 🔑 Features:
- 📂 Browse sign videos by **category**, **word**, or **signer**.
- 🌟 **Favorites**: Save videos for quick access.
- 📷 **Translate**: Upload a video (one word or a full sentence) and get its meaning in text.
- 🧠 Perfect for learning, practicing, and testing ArSL knowledge.

---

## 🚀 Technologies Used

| Component            | Tech Stack |
|---------------------|------------|
| Preprocessing       | OpenCV, Cython, NumPy |
| Feature Extraction  | Zernike Moments, EfficientNetB0 |
| Models              | CNNs, BiLSTMs, Transformers |
| Backend             | Flask (for model inference) |
| Mobile App          | Flutter & Dart |
| Visualization       | Matplotlib, Seaborn |
| Deployment          | Local & Mobile (Flutter) |

---

## 📜 License

MIT License. Feel free to use and modify for research or educational purposes.

---

## 🤝 Contributing

We welcome contributions and improvements! If you find bugs, want to add new features, or improve documentation, feel free to fork and submit a pull request.


