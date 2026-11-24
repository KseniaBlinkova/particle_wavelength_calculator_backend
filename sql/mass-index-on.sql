CREATE INDEX IF NOT EXISTS idx_particles_published_mass_id
    ON particles (mass DESC NULLS LAST, id ASC)
    WHERE status = 'published';
ANALYZE particles;
