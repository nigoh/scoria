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

      <h1 className="text-2xl font-bold text-foreground">利用規約</h1>
      <p className="mt-2 text-sm text-muted-foreground">
        最終更新日: 2026年3月18日
      </p>

      <div className="mt-8 space-y-8 text-sm leading-relaxed text-foreground">
        <section>
          <h2 className="text-lg font-semibold">1. サービスの概要</h2>
          <p className="mt-2">
            Scoria（以下「本サービス」）は、学術研究に関する AI
            プロンプトを自動生成するウェブアプリケーションです。本サービスを利用することで、以下の利用規約に同意したものとみなします。
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold">2. 免責事項</h2>
          <ul className="mt-2 list-inside list-disc space-y-1 text-muted-foreground">
            <li>
              本サービスが生成するプロンプトは参考情報であり、その品質・正確性・適切性を保証するものではありません
            </li>
            <li>
              LLM API を通じて得られる応答の正確性・信頼性について、本サービスは一切の責任を負いません
            </li>
            <li>
              本サービスの利用により生じた損害について、運営者は一切の責任を負いません
            </li>
            <li>
              学術論文の投稿や研究成果の発表にあたっては、ユーザー自身の責任で内容を検証してください
            </li>
          </ul>
        </section>

        <section>
          <h2 className="text-lg font-semibold">3. API キーの管理</h2>
          <p className="mt-2">
            ユーザーが本サービスに設定する LLM API
            キーの管理はユーザー自身の責任です。API キーの漏洩、不正利用、およびそれに伴う費用について、本サービスは責任を負いません。
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold">4. 禁止事項</h2>
          <p className="mt-2">
            本サービスの利用にあたり、以下の行為を禁止します。
          </p>
          <ul className="mt-2 list-inside list-disc space-y-1 text-muted-foreground">
            <li>本サービスの不正利用や妨害行為</li>
            <li>
              本サービスを利用した違法行為、または公序良俗に反する行為
            </li>
            <li>
              本サービスのリバースエンジニアリング（オープンソースの範囲を除く）
            </li>
            <li>他のユーザーに迷惑をかける行為</li>
          </ul>
        </section>

        <section>
          <h2 className="text-lg font-semibold">5. 知的財産権</h2>
          <p className="mt-2">
            本サービスで生成されたプロンプトの著作権はユーザーに帰属します。本サービスの UI
            デザイン、ロゴ、ソフトウェアに関する知的財産権は運営者に帰属します。
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold">
            6. サービスの変更・停止・終了
          </h2>
          <p className="mt-2">
            運営者は事前の通知なく本サービスの内容を変更、または一時的もしくは永久的にサービスを停止・終了できるものとします。
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold">7. 規約の変更</h2>
          <p className="mt-2">
            本規約は予告なく変更される場合があります。変更後の利用規約は本サービス上に掲示した時点で効力を生じるものとします。
          </p>
        </section>
      </div>
    </PageContainer>
  );
}
