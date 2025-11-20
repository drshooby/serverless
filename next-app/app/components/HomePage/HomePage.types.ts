export interface VideoRecord {
  videoId: string;
  jobId: string;
  outputKey: string;
  thumbnailUrl: string;
  createdAt: string;
}

export interface VideoPlayerProps {
  videoUrl: string | null;
  loading: boolean;
}

export interface HomePageProps {
  username: string;
  email: string;
  gatewayURI: string;
  onSignOut: () => void;
}