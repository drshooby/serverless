export interface Montage {
  id: number;
  thumbnail: string;
  title: string;
  url: string;
}

export interface VideoPlayerProps {
  videoUrl: string | null;
  loading: boolean;
}

export interface HomePageProps {
  username: string;
  email: string;
  bucketURL: string
  onSignOut: () => void;
}