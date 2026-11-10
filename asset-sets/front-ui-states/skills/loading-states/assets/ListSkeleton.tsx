type ListSkeletonProps = { rows?: number; label: string };

// Adapt the placeholder rows to the real list's layout and styling.
export function ListSkeleton({ rows = 5, label }: ListSkeletonProps) {
  return (
    <ul aria-busy="true" aria-label={label}>
      {Array.from({ length: rows }, (_, index) => (
        <li key={index} aria-hidden="true">
          …
        </li>
      ))}
    </ul>
  );
}
