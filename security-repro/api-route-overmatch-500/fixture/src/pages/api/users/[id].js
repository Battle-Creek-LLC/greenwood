export async function handler(request, { params }) {
  // typical user code: assumes the route only matches when `id` is present
  const id = params.id.toUpperCase();
  return new Response(JSON.stringify({ id }), {
    headers: { "Content-Type": "application/json" },
  });
}
