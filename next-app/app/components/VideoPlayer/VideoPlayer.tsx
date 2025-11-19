"use client";

import styles from "./VideoPlayer.module.css";

import { VideoPlayerProps } from "./VideoPlayer.types";

export function VideoPlayer({ videoName, overrides = {} }: VideoPlayerProps) {
  return (
    <div
      className={styles.mainVideoContainer}
      style={overrides.mainVideoContainer}
    >
      <div className={styles.videoWrapper}>
        <video playsInline preload="metadata" className={styles.video} controls>
          {/* assuming you have your video in /public */}
          <source src={videoName} type="video/mp4" />
          Your browser does not support the video tag.
        </video>
      </div>
    </div>
  );
}
