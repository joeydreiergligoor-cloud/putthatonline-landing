export default function SkeletonGrid() {
  return (
    <div className="max-w-5xl mx-auto px-6 pb-20" aria-hidden="true">
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {Array.from({ length: 3 }).map((_, i) => (
          <div key={i} className="rounded-card border border-border p-5">
            <div className="skeleton h-5 w-2/3 rounded" />
            <div className="skeleton h-3 w-full rounded mt-3" />
            <div className="skeleton h-3 w-4/5 rounded mt-2" />
            <div className="skeleton h-3 w-1/3 rounded mt-5" />
          </div>
        ))}
      </div>
    </div>
  );
}
