import { useState } from "react";
import { Upload } from "lucide-react";
import styles from "./HomePage.module.css";
import type { HomePageProps, Montage } from "./HomePage.types.ts";
import { VideoPlayer } from "@/app/components/VideoPlayer";
import { SignOutButton } from "@/app/components/SignOutButton";
import { VideoLoading } from "@/app/components/VideoLoading";
import { uploadToS3, processMontage } from "@/app/functions";

export function HomePage({ username = "Agent" }: HomePageProps) {
  const [showUpload, setShowUpload] = useState<boolean>(true);
  const [currentVideo, setCurrentVideo] = useState<string | null>(null);
  const [processing, setProcessing] = useState<boolean>(false);
  const [dragActive, setDragActive] = useState<boolean>(false);

  const previousMontages: Montage[] = [];

  const handleDrag = (e: React.DragEvent<HTMLLabelElement>) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true);
    } else if (e.type === "dragleave") {
      setDragActive(false);
    }
  };

  const handleDrop = (e: React.DragEvent<HTMLLabelElement>) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);

    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFile(e.dataTransfer.files[0]);
    }
  };

  const handleFileInput = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      handleFile(e.target.files[0]);
    }
  };

  const handleFile = async (file: File) => {
    console.log("File uploaded:", file.name);
    setProcessing(true);

    try {
      // Upload to S3
      const uploadResult = await uploadToS3({
        file,
        userId: username,
      });

      if (!uploadResult.success) {
        throw new Error(uploadResult.error);
      }

      // Start montage processing
      const processResult = await processMontage({
        s3Key: uploadResult.s3Key,
        userId: username,
      });

      if (!processResult.success) {
        throw new Error(processResult.error);
      }

      // TODO: Poll for completion or set up websocket
      // For now, create local preview
      const videoUrl = URL.createObjectURL(file);
      setCurrentVideo(videoUrl);
      setProcessing(false);
      setShowUpload(false);
    } catch (error) {
      console.error("Error processing video:", error);
      setProcessing(false);
      // TODO: Show error message to user
    }
  };

  const loadMontage = (montage: Montage) => {
    if (processing) return;
    setCurrentVideo(montage.url);
    setShowUpload(false);
  };

  const showUploadScreen = () => {
    if (processing) return;
    setShowUpload(true);
    setCurrentVideo(null);
  };

  return (
    <div className={styles.container}>
      <header className={styles.header}>
        <div className={styles.greeting}>Hi, {username}</div>
        <h1 className={styles.logo}>radiant</h1>
        <SignOutButton />
      </header>

      <main className={styles.mainContent}>
        <section className={styles.playerSection}>
          <div className={styles.videoContainer}>
            {processing ? (
              <VideoLoading />
            ) : showUpload ? (
              <label
                className={`${styles.uploadZone} ${
                  dragActive ? styles.dragActive : ""
                }`}
                onDragEnter={handleDrag}
                onDragLeave={handleDrag}
                onDragOver={handleDrag}
                onDrop={handleDrop}
              >
                <Upload
                  className={styles.uploadIcon}
                  size={48}
                  strokeWidth={2}
                />
                <div className={styles.uploadText}>Drop your clip here</div>
                <div className={styles.uploadSubtext}>or click to browse</div>
                <input
                  type="file"
                  accept="video/*"
                  onChange={handleFileInput}
                />
              </label>
            ) : (
              <VideoPlayer videoName={currentVideo as string} />
            )}
          </div>

          {!showUpload && !processing && (
            <div className={styles.actionSection}>
              <button
                className={styles.uploadNewButton}
                onClick={showUploadScreen}
              >
                <Upload size={20} />
                Upload New Clip
              </button>
            </div>
          )}
        </section>

        <section className={styles.montagesSection}>
          <h2 className={styles.sectionTitle}>Previous Montages</h2>
          <div
            className={`${styles.montagesGrid} ${
              processing ? styles.disabled : ""
            }`}
          >
            {previousMontages.map((montage) => (
              <div
                key={montage.id}
                className={styles.montageCard}
                onClick={() => loadMontage(montage)}
                style={{ cursor: processing ? "not-allowed" : "pointer" }}
              >
                <img
                  src={montage.thumbnail}
                  alt={montage.title}
                  className={styles.montageThumbnail}
                />
                <div className={styles.montageTitle}>{montage.title}</div>
              </div>
            ))}
          </div>
        </section>
      </main>
    </div>
  );
}
