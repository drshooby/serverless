import styles from "./Loading.module.css";

export function Loading({ message = "Loading" }: { message?: string }) {
  return (
    <div className={styles.loadingContainer}>
      <div className={styles.loadingContent}>
        <span>{message}</span>
        <div className={styles.loader}></div>
      </div>
    </div>
  );
}
