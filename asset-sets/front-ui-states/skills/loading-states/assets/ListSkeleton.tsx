type ListSkeletonProps = { rows?: number; label?: string }

// Esqueleto con la forma de una fila de lista. Mismo alto que la fila real.
export function ListSkeleton({ rows = 5, label = 'Cargando' }: ListSkeletonProps) {
  return (
    <ul aria-busy="true" aria-label={label} className="divide-y divide-rule border border-rule bg-surface">
      {Array.from({ length: rows }, (_, index) => (
        <li key={index} className="flex animate-pulse items-center gap-4 px-5 py-4">
          <span className="size-11 shrink-0 rounded-full bg-sunken" />
          <div className="flex-1 space-y-2">
            <span className="block h-4 w-40 rounded-xs bg-sunken" />
            <span className="block h-3 w-56 rounded-xs bg-sunken/70" />
          </div>
          <span className="h-6 w-16 rounded-full bg-sunken" />
        </li>
      ))}
    </ul>
  )
}
