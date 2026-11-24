-- 070-tasks.sql
-- Example child entity: the composite FK guarantees a task never points to another tenant's project.
CREATE TABLE IF NOT EXISTS public.tasks (
  id                uuid        NOT NULL DEFAULT uuidv7(),
  tenant_id         uuid        NOT NULL,
  project_id        uuid        NOT NULL,
  title             text        NOT NULL,
  status            text        NOT NULL DEFAULT 'todo',
  assignee_user_id  uuid        NULL,
  due_on            date        NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_tasks PRIMARY KEY (id),
  CONSTRAINT fk_tasks_tenant_id_project_id FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.projects (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_tasks_assignee_user_id FOREIGN KEY (assignee_user_id) REFERENCES public.users (id) ON DELETE SET NULL,
  CONSTRAINT ck_tasks_status CHECK (status IN ('todo', 'doing', 'done'))
);

CREATE INDEX IF NOT EXISTS idx_tasks_tenant_id_project_id_status ON public.tasks (tenant_id, project_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_tenant_id_assignee_user_id ON public.tasks (tenant_id, assignee_user_id)
  WHERE assignee_user_id IS NOT NULL;

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks FORCE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies
                 WHERE schemaname = 'public' AND tablename = 'tasks' AND policyname = 'tenant_isolation') THEN
    CREATE POLICY tenant_isolation ON public.tasks
      USING (tenant_id = public.current_tenant_id())
      WITH CHECK (tenant_id = public.current_tenant_id());
  END IF;
END $$;

COMMENT ON TABLE public.tasks IS 'Example child entity with tenant-safe composite FK to projects';
