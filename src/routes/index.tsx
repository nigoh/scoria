import { createBrowserRouter } from "react-router-dom";
import { AppShell } from "@/components/layout/AppShell";

export const router = createBrowserRouter([
  {
    element: <AppShell />,
    children: [
      {
        path: "/",
        lazy: () => import("./home/page"),
      },
      {
        path: "/builder",
        lazy: () => import("./builder/page"),
      },
      {
        path: "/settings",
        lazy: () => import("./settings/page"),
      },
      {
        path: "/privacy",
        lazy: () => import("./privacy/page"),
      },
      {
        path: "/terms",
        lazy: () => import("./terms/page"),
      },
    ],
  },
]);
