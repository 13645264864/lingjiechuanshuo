-- Server-owned cultivation prototype. No client may update currency directly.
CREATE TABLE public.cultivation_characters (
  owner_id text PRIMARY KEY,
  display_name text NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 16),
  realm integer NOT NULL DEFAULT 0 CHECK (realm >= 0),
  cultivation bigint NOT NULL DEFAULT 0 CHECK (cultivation >= 0),
  last_claim_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.cultivation_characters ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.cultivation_characters FROM anon, authenticated;
GRANT SELECT ON public.cultivation_characters TO authenticated;
CREATE POLICY character_read_own ON public.cultivation_characters
  FOR SELECT TO authenticated USING (owner_id = auth.uid());

CREATE FUNCTION public.create_cultivation_character(p_display_name text)
RETURNS public.cultivation_characters
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid text := auth.uid(); v_row public.cultivation_characters;
BEGIN
  IF v_uid IS NULL OR v_uid = '' OR auth.role() <> 'authenticated' THEN
    RAISE EXCEPTION 'login_required' USING ERRCODE = '42501';
  END IF;
  IF p_display_name IS NULL OR char_length(btrim(p_display_name)) NOT BETWEEN 1 AND 16 THEN
    RAISE EXCEPTION 'invalid_display_name' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.cultivation_characters(owner_id, display_name)
    VALUES (v_uid, btrim(p_display_name)) ON CONFLICT (owner_id) DO NOTHING;
  SELECT * INTO v_row FROM public.cultivation_characters WHERE owner_id = v_uid;
  RETURN v_row;
END; $$;

CREATE FUNCTION public.claim_cultivation()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid text := auth.uid(); v_row public.cultivation_characters;
  v_now timestamptz; v_seconds bigint; v_reward bigint;
BEGIN
  IF v_uid IS NULL OR v_uid = '' OR auth.role() <> 'authenticated' THEN
    RAISE EXCEPTION 'login_required' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_row FROM public.cultivation_characters WHERE owner_id = v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'character_required' USING ERRCODE = '22023'; END IF;
  v_now := clock_timestamp();
  v_seconds := greatest(0, floor(extract(epoch FROM v_now - v_row.last_claim_at))::bigint);
  -- Prototype rate: 1 point/minute, max 12 hours. Preserve the sub-minute remainder.
  v_reward := least(v_seconds, 43200) / 60;
  UPDATE public.cultivation_characters
    SET cultivation = cultivation + v_reward,
        last_claim_at = CASE WHEN v_seconds >= 43200 THEN v_now
          ELSE last_claim_at + make_interval(secs => (v_reward * 60)::double precision) END
    WHERE owner_id = v_uid RETURNING * INTO v_row;
  RETURN jsonb_build_object('character', to_jsonb(v_row), 'reward', v_reward);
END; $$;
REVOKE ALL ON FUNCTION public.create_cultivation_character(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.claim_cultivation() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_cultivation_character(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_cultivation() TO authenticated;
