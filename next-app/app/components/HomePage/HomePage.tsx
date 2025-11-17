import { useState } from "react";
import { Upload } from "lucide-react";
import styles from "./HomePage.module.css";
import type { HomePageProps, Montage } from "./HomePage.types.ts";
import { VideoPlayer } from "@/app/components/VideoPlayer";
import { SignOutButton } from "@/app/components/SignOutButton";
import { VideoLoading } from "@/app/components/VideoLoading";
import { uploadToS3 } from "@/app/functions";
import { Modal } from "@/app/components/Modal";
import { ModalProps } from "@/app/components/Modal/Modal.types";

export function HomePage({
  username,
  email,
  gatewayURI,
  onSignOut,
}: HomePageProps) {
  const [showUpload, setShowUpload] = useState<boolean>(true);
  const [currentVideo, setCurrentVideo] = useState<string | null>(null);
  const [processing, setProcessing] = useState<boolean>(false);
  const [dragActive, setDragActive] = useState<boolean>(false);

  const [isModalOpen, setModalOpen] = useState(false);
  const [modalData, setModalData] = useState<ModalProps | undefined>(undefined);

  // const previousMontages: Montage[] = [];

  const handleFailModal = (errorDetails: ModalProps) => {
    console.log("handleFailModal called with:", errorDetails);
    setModalOpen(true);
    setModalData(errorDetails);
    console.log("Modal state updated");
  };

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
      e.target.value = "";
    }
  };

  const handleFile = async (file: File) => {
    console.log("Attempting upload:", file.name);

    const MAX_SIZE_MB = 25;
    const fileSizeMB = file.size / (1024 * 1024);

    if (fileSizeMB > MAX_SIZE_MB) {
      const title = "File too large!";
      const message = `(${fileSizeMB.toFixed(
        1
      )} MB). Please upload videos under ${MAX_SIZE_MB} MB (~20 seconds).`;
      handleFailModal({ title, message });
      return;
    }

    console.log("Beginning processing:");

    setProcessing(true);
    setShowUpload(false);

    try {
      // Upload to S3
      const uploadResult = await uploadToS3({
        file,
        userEmail: email,
        gatewayURI,
      });

      if (!uploadResult.success) {
        throw new Error(uploadResult.error);
      }

      console.log(uploadResult.s3Key);
      console.log(uploadResult.s3Url);

      // For now, create local preview
      // const videoUrl = URL.createObjectURL(file);
      // setCurrentVideo(videoUrl);
      // setProcessing(false);
    } catch (error) {
      console.error("Error processing video:", error);
      // TODO: Show error message to user
    } finally {
      setProcessing(false);
      setShowUpload(true);
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
        <h1 className={`${styles.logo} ${processing ? styles.processing : ""}`}>
          radiant
        </h1>
        <div className={styles.signOutSection}>
          <SignOutButton onClick={onSignOut} />
        </div>
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

        {/* <section className={styles.montagesSection}>
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
        </section> */}

        {isModalOpen && modalData && (
          <Modal
            data={{ title: modalData.title, message: modalData.message }}
            onClose={() => {
              setModalOpen(false);
              setModalData(undefined);
            }}
          />
        )}
      </main>
    </div>
  );
}
