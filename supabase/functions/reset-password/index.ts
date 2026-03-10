import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
      },
    });
  }

  try {
    const { email, new_password: newPassword } = await request.json();

    if (!email || !newPassword) {
      return Response.json(
        { error: "email and new_password are required" },
        { status: 400, headers: { "Access-Control-Allow-Origin": "*" } },
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: usersData, error: listError } = await admin.auth.admin.listUsers();
    if (listError != null) {
      return Response.json(
        { error: listError.message },
        { status: 500, headers: { "Access-Control-Allow-Origin": "*" } },
      );
    }

    const targetUser = usersData.users.find((user) => user.email === email);
    if (targetUser == null) {
      return Response.json(
        { error: "User not found" },
        { status: 404, headers: { "Access-Control-Allow-Origin": "*" } },
      );
    }

    const { error: updateError } = await admin.auth.admin.updateUserById(
      targetUser.id,
      { password: newPassword },
    );

    if (updateError != null) {
      return Response.json(
        { error: updateError.message },
        { status: 500, headers: { "Access-Control-Allow-Origin": "*" } },
      );
    }

    return Response.json(
      { message: "รีเซ็ตรหัสผ่านสำเร็จ" },
      { status: 200, headers: { "Access-Control-Allow-Origin": "*" } },
    );
  } catch (error) {
    return Response.json(
      { error: error instanceof Error ? error.message : "Unknown error" },
      { status: 500, headers: { "Access-Control-Allow-Origin": "*" } },
    );
  }
});
