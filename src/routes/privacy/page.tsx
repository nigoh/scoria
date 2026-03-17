import { Link } from "react-router-dom";
import { PageContainer } from "@/components/layout/PageContainer";
import { ArrowLeft } from "@phosphor-icons/react";

export function Component() {
  return (
    <PageContainer className="max-w-3xl">
      <Link
        to="/"
        className="mb-6 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft size={16} />
        トップに戻る
      </Link>

      <h1 className="text-2xl font-bold text-foreground">
        プライバシーポリシー
      </h1>
      <p className="mt-2 text-sm text-muted-foreground">
        最終更新日: 2026年3月18日
      </p>

      <div className="mt-8 space-y-8 text-sm leading-relaxed text-foreground">
        <section>
          <h2 className="text-lg font-semibold">1. はじめに</h2>
          <p className="mt-2">
            Scoria（以下「本サービス」）は、学術研究プロンプト生成ツールです。本サービスはユーザーのプライバシーを尊重し、個人情報の保護に努めます。
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold">2. データの取り扱い</h2>
          <p className="mt-2">
            本サービスは完全にクライアントサイド（ブラウザ内）で動作します。ユーザーのデータは一切外部サーバーに送信・保存されません。
          </p>
          <ul className="mt-2 list-inside list-disc space-y-1 text-muted-foreground">
            <li>
              すべてのデータ（設定、プロンプト履歴等）はブラウザの localStorage / sessionStorage に保存されます
            </li>
            <li>
              バックエンドサーバーやデータベースは存在しません
            </li>
            <li>
              本サービス自体がユーザーデータを収集・送信することはありません
            </li>
          </ul>
        </section>

        <section>
          <h2 className="text-lg font-semibold">3. API キーの管理</h2>
          <p className="mt-2">
            ユーザーが設定する LLM API キー（Anthropic、OpenAI 等）は、ブラウザ内で AES-GCM 方式により暗号化した上で localStorage に保存されます。
          </p>
          <ul className="mt-2 list-inside list-disc space-y-1 text-muted-foreground">
            <li>API キーが本サービスのサーバーに送信されることはありません</li>
            <li>
              LLM API への通信はユーザーのブラウザから各プロバイダー（api.anthropic.com、api.openai.com 等）へ直接送信されます
            </li>
            <li>各プロバイダーのプライバシーポリシーも併せてご確認ください</li>
          </ul>
        </section>

        <section>
          <h2 className="text-lg font-semibold">4. Cookie・アクセス解析</h2>
          <p className="mt-2">
            本サービスは現時点で Cookie やアクセス解析ツールを使用していません。将来的に導入する場合は、本ポリシーを更新し事前にお知らせします。
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold">5. データの削除</h2>
          <p className="mt-2">
            ブラウザの開発者ツールや設定画面からいつでもすべてのローカルデータを削除できます。データ削除後の復元はできません。
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold">6. ポリシーの変更</h2>
          <p className="mt-2">
            本ポリシーは予告なく変更される場合があります。重要な変更がある場合は、本サービス上でお知らせします。
          </p>
        </section>
      </div>
    </PageContainer>
  );
}
