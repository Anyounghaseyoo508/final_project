import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });
  }

  const { prompt, imageUrls } = await req.json();

  if (!prompt) {
    return new Response("Bad Request", { status: 400, headers: corsHeaders });
  }

  const geminiKey = Deno.env.get("GEMINI_API_KEY");

  // สร้าง parts — ถ้ามีรูปให้ดึงมาแนบด้วย
  const parts: any[] = [{ text: prompt }];

  if (imageUrls && Array.isArray(imageUrls)) {
    for (const url of imageUrls) {
      const imgRes = await fetch(url);
      const buffer = await imgRes.arrayBuffer();
      const uint8Array = new Uint8Array(buffer);
      let binary = '';
      const chunkSize = 8192;
      for (let i = 0; i < uint8Array.length; i += chunkSize) {
        const chunk = uint8Array.subarray(i, i + chunkSize);
        binary += String.fromCharCode(...chunk);
      }
      const base64 = btoa(binary);

      parts.push({
        inline_data: {
          mime_type: "image/jpeg",
          data: base64,
        },
      });
    }
  }

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts }],
      }),
    }
  );

  const data = await response.json();
  return new Response(JSON.stringify(data), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});