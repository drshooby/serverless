import styles from "./Loading.module.css";

export function Loading({ message = "Loading..." }: { message?: string }) {
  return (
    <div className={styles.loadingContainer}>
      <div className={styles.loader}>{message}</div>
    </div>
  );
}
