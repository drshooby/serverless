import { useEffect, useState, useMemo } from "react";
import { Upload } from "lucide-react";
import styles from "./HomePage.module.css";
import type { HomePageProps, VideoRecord } from "./HomePage.types.ts";
import { VideoPlayer } from "@/app/components/VideoPlayer";
import { SignOutButton } from "@/app/components/SignOutButton";
import { VideoLoading } from "@/app/components/VideoLoading";
import { MontageClient } from "@/app/functions";
import { Modal } from "@/app/components/Modal";
import { ModalProps } from "@/app/components/Modal/Modal.types";
import Image from "next/image";

export function HomePage({
  username,
  email,
  gatewayURI,
  onSignOut,
}: HomePageProps) {
  const backendCompatibleEmail = email.replace("@", "_at_");
  const client = useMemo(
    () => new MontageClient(gatewayURI, backendCompatibleEmail),
    [gatewayURI, backendCompatibleEmail]
  );
  const [showUpload, setShowUpload] = useState<boolean>(true);
  const [currentVideo, setCurrentVideo] = useState<string | null>(null);
  const [processing, setProcessing] = useState<boolean>(false);
  const [dragActive, setDragActive] = useState<boolean>(false);

  const [isModalOpen, setModalOpen] = useState(false);
  const [modalData, setModalData] = useState<ModalProps | undefined>(undefined);
  const [previousMontages, setPreviousMontages] = useState<VideoRecord[]>([]);

  const fetchVideos = async () => {
    try {
      const videos = await client.getPastMontages();
      setPreviousMontages(videos);
    } catch (error) {
      console.error("Failed to fetch videos:", error);
    }
  };

  useEffect(() => {
    fetchVideos();
  }, []);

  const handleFailModal = (errorDetails: ModalProps) => {
    setModalOpen(true);
    setModalData(errorDetails);
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
      handleUpload(e.dataTransfer.files[0]);
    }
  };

  const handleFileInput = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      handleUpload(e.target.files[0]);
      e.target.value = "";
    }
  };

  const handleUpload = async (file: File) => {
    console.log("Attempting upload:", file.name);

    const MAX_SIZE_MB = 300;
    const fileSizeMB = file.size / (1024 * 1024);

    if (fileSizeMB > MAX_SIZE_MB) {
      const title = "File too large!";
      const message = `(${fileSizeMB.toFixed(
        1
      )} MB). Please upload videos under ${MAX_SIZE_MB} MB.`;
      handleFailModal({ title, message });
      return;
    }

    console.log("Beginning processing:");

    setProcessing(true);
    setShowUpload(false);

    try {
      // Upload to S3
      const uploadResult = await client.uploadToS3({
        file,
      });

      if (!uploadResult.success) {
        throw new Error(uploadResult.error);
      }

      await fetchVideos();
    } catch (error) {
      handleFailModal({
        title: "Error processing your video!",
        message:
          error instanceof Error ? error.message : "Unknown error occurred",
      });
    } finally {
      setProcessing(false);
      setShowUpload(true);
    }
  };

  const loadMontage = async (video: VideoRecord) => {
    if (processing) return;

    try {
      const url = await client.getVideoURL(video.videoId);
      console.log(url);
      setCurrentVideo(url);
      setShowUpload(false);
    } catch (error) {
      console.error("Failed to load video:", error);
    }
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
              <VideoPlayer
                key={currentVideo}
                videoName={currentVideo as string}
              />
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
            {previousMontages.map((video, index) => (
              <div
                key={video.videoId}
                className={styles.montageCard}
                onClick={() => loadMontage(video)}
                style={{ cursor: processing ? "not-allowed" : "pointer" }}
              >
                {index === 0 && (
                  <div className={styles.latestBadge}>Latest</div>
                )}
                <div className={styles.thumbnailContainer}>
                  {video.thumbnailUrl ? (
                    <Image
                      src={video.thumbnailUrl}
                      alt={
                        video.outputKey.split("/").pop()?.replace(".mp4", "") ||
                        "Montage"
                      }
                      fill
                      className={styles.thumbnail}
                      sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
                    />
                  ) : (
                    <div className={styles.videoPlaceholder}>
                      <svg
                        className={styles.videoIcon}
                        width="60"
                        height="60"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                      >
                        <polygon points="5 3 19 12 5 21 5 3" />
                      </svg>
                    </div>
                  )}
                  <div className={styles.playOverlay}>
                    <svg
                      width="48"
                      height="48"
                      viewBox="0 0 24 24"
                      fill="white"
                      opacity="0.9"
                    >
                      <polygon points="5 3 19 12 5 21 5 3" />
                    </svg>
                  </div>
                </div>
                <div className={styles.montageInfo}>
                  <div className={styles.montageTitle}>
                    {video.outputKey.split("/").pop()?.replace(".mp4", "") ||
                      "Montage"}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </section>

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
